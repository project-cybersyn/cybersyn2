--------------------------------------------------------------------------------
-- Allocation phase
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local mlib = require("__cybersyn2__.lib.math")
local siglib = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings
local Node = _G.cs2.Node

local strace = stlib.strace
local TRACE = stlib.TRACE
local DEBUG = stlib.DEBUG
local ERROR = stlib.ERROR
local tsort = table.sort
local map = tlib.map
local t_map_a = tlib.t_map_a
local filter = tlib.filter
local concat = tlib.concat
local min = math.min
local pos_get = mlib.pos_get
local sqrt = math.sqrt
local key_is_fluid = siglib.key_is_fluid
local key_to_stacksize = siglib.key_to_stacksize
local empty = tlib.empty
local order_provided_qty = cs2.order_provided_qty
local order_requested_qty = cs2.order_requested_qty

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

---A logistics allocation.
---@class Cybersyn.Internal.LogisticsAllocation
---@field public from Cybersyn.Node
---@field public from_inv Cybersyn.Inventory
---@field public from_thresh uint
---@field public to Cybersyn.Node
---@field public to_inv Cybersyn.Inventory
---@field public to_thresh uint
---@field public item SignalKey
---@field public qty int
---@field public prio int
---@field public stack_size uint Stack size, 1 for fluids
---@field public is_fluid boolean

--------------------------------------------------------------------------------
-- Util
--------------------------------------------------------------------------------

---@param self Cybersyn.LogisticsThread
---@param item SignalKey
---@param producer Cybersyn.Node
---@param producer_logistics_type string
---@param consumer Cybersyn.Node
---@param consumer_logistics_type string
---@param consumer_prio integer
---@param get_production_info fun(node: Cybersyn.Node, item: SignalKey): integer, integer, Cybersyn.Inventory?
---@param get_consumption_info fun(node: Cybersyn.Node, item: SignalKey): integer, integer, Cybersyn.Inventory?
local function alloc_item_generic(
	self,
	item,
	producer,
	producer_logistics_type,
	consumer,
	consumer_logistics_type,
	consumer_prio,
	get_production_info,
	get_consumption_info
)
	-- Verify consumer wants item
	local consumed, consumer_in_t, consumer_inv =
		get_consumption_info(consumer, item)
	if consumed == 0 or not consumer_inv then
		return self:remove_from_logistics_set(
			consumer_logistics_type,
			consumer.id,
			item
		)
	end

	-- Verify producer has item
	local avail, producer_out_t, producer_inv =
		get_production_info(producer, item)
	if avail == 0 or not producer_inv then
		return self:remove_from_logistics_set(
			producer_logistics_type,
			producer.id,
			item
		)
	end

	-- Honor consumer capacity.
	local item_stack_capacity, fluid_capacity = consumer_inv:get_capacities()
	if item_stack_capacity or fluid_capacity then
		-- Rare case; capacity should not be used often.
		local is_fluid = key_is_fluid(item)
		if is_fluid and fluid_capacity then
			local _, used_fluid_capacity = consumer_inv:get_used_capacities()
			local avail_fluid_capacity = fluid_capacity - used_fluid_capacity
			consumed = min(consumed, avail_fluid_capacity)
		elseif not is_fluid and item_stack_capacity then
			local used_item_stack_capacity = consumer_inv:get_used_capacities()
			local avail_item_capacity = (
				item_stack_capacity - used_item_stack_capacity
			) * (key_to_stacksize(item) or 0)
			consumed = min(consumed, avail_item_capacity)
		end
	end

	local qty = min(consumed, avail)

	if qty >= producer_out_t and qty >= consumer_in_t then
		return self:allocate(
			producer,
			producer_inv,
			producer_out_t,
			consumer,
			consumer_inv,
			consumer_in_t,
			item,
			qty,
			consumer_prio
		)
	end
end

---@param to Cybersyn.TrainStop
local function make_distance_busy_score_calculator(to)
	local to_x, to_y = pos_get(to.entity.position)
	---@param from Cybersyn.TrainStop
	return function(from)
		local stop_b_x, stop_b_y = pos_get(from.entity.position)
		local dx, dy = stop_b_x - to_x, stop_b_y - to_y
		local distance = sqrt(dx * dx + dy * dy)
		local busy = from:get_occupancy()
		return distance + busy * 500
	end
end

local function make_distance_busy_sort_fn(to)
	local calc = make_distance_busy_score_calculator(to)
	return function(a, b) return calc(a[1]) < calc(b[1]) end
end

--------------------------------------------------------------------------------
-- Allocator primitives
--------------------------------------------------------------------------------

---@param from_node Cybersyn.Node
---@param from_inv Cybersyn.Inventory
---@param from_thresh uint
---@param to_node Cybersyn.Node
---@param to_inv Cybersyn.Inventory
---@param to_thresh uint
---@param item SignalKey
---@param qty integer
---@param prio integer
function LogisticsThread:allocate(
	from_node,
	from_inv,
	from_thresh,
	to_node,
	to_inv,
	to_thresh,
	item,
	qty,
	prio
)
	if qty <= 0 then return end
	from_inv:add_single_item_outflow(item, qty)
	to_inv:add_single_item_inflow(item, qty)
	local is_fluid = key_is_fluid(item)
	---@type Cybersyn.Internal.LogisticsAllocation
	local allocation = {
		from = from_node,
		from_inv = from_inv,
		from_thresh = from_thresh,
		to = to_node,
		to_inv = to_inv,
		to_thresh = to_thresh,
		item = item,
		qty = qty,
		prio = prio,
		is_fluid = is_fluid,
		stack_size = is_fluid and 1 or (key_to_stacksize(item) or 1),
	}
	-- strace(
	-- 	DEBUG,
	-- 	"cs2",
	-- 	"alloc",
	-- 	"message",
	-- 	item,
	-- 	"from",
	-- 	from_node.id,
	-- 	"to",
	-- 	to_node.id,
	-- 	"qty",
	-- 	qty
	-- )
	self.allocations[#self.allocations + 1] = allocation
	local from_id = from_node.id
	local from_allocs = self.allocs_from[from_id]
	if not from_allocs then
		from_allocs = {}
		self.allocs_from[from_id] = from_allocs
	end
	from_allocs[#from_allocs + 1] = allocation
end

---@param alloc Cybersyn.Internal.LogisticsAllocation
function LogisticsThread:refund_allocation(alloc)
	local item = alloc.item
	local qty = -alloc.qty
	alloc.from_inv:add_single_item_outflow(item, qty)
	alloc.to_inv:add_single_item_inflow(item, qty)
	alloc.qty = 0
end

--------------------------------------------------------------------------------
-- Neoinventory
--------------------------------------------------------------------------------

---@param networks1 SignalSet
---@param networks2 SignalSet
local function network_match(networks1, networks2)
	for name in pairs(networks1 or empty) do
		if (networks2 or empty)[name] then return true end
	end
	return false
end

---@param item SignalKey
---@param requester Cybersyn.Order
function LogisticsThread:alloc_item_to(item, requester)
	local providers = self.providers[item]
	if not providers or #providers == 0 then
		-- This shouldn't happen since the list of items is generated based on
		-- existence of providers
		return
	end
	local requester_networks = requester.networks
	local requester_stop = cs2.get_stop(requester.node_id)
	if not requester_stop then return end
	local requester_x, requester_y = pos_get(requester_stop.entity.position)
	local request_thresh = requester.thresholds_in[item]
	local request_qty = order_requested_qty(requester, item)

	-- Filter for providers that still have inventory. Optimize by replacing
	-- overall list of providers.
	providers = filter(providers, function(provider)
		if order_provided_qty(provider, item) <= 0 then return false end
		return true
	end)
	self.providers[item] = providers

	-- Filter for netmatches.
	providers = filter(providers, function(provider)
		-- Netmask matches
		if not network_match(requester_networks, provider.networks) then
			return false
		end
		return true
	end)

	-- Sort providers
	tsort(providers, function(a, b)
		-- Ability to make an above-threshold delivery
		-- A can deliver, B can't = true
		-- A can't deliver, B can = false
		-- Any other situation = fallthrough
		local a_thresh = a.thresholds_out[item]
		local a_qty = min(order_provided_qty(a, item), request_qty)
		local a_can_deliver = (a_qty >= a_thresh) and (a_qty >= request_thresh)
		local b_thresh = b.thresholds_out[item]
		local b_qty = min(order_provided_qty(b, item), request_qty)
		local b_can_deliver = (b_qty >= b_thresh) and (b_qty >= request_thresh)
		if a_can_deliver and not b_can_deliver then return true end
		if not a_can_deliver and b_can_deliver then return false end
		-- Priority
		if a.priority > b.priority then return true end
		-- Distance-busy equation
		-- TODO: distance
		return a.busy_value < b.busy_value
	end)

	-- Allocate from providers until the requested amount is met
	for i = 1, #providers do
		local provider = providers[i]
		local qty = min(request_qty, order_provided_qty(provider, item))
		if qty > 0 then
			local provider_stop = cs2.get_stop(provider.node_id, true)
			if provider_stop then
				-- TODO: honor requester capacity (See above)

				self:allocate(
					provider_stop,
					provider.inventory,
					provider.thresholds_out[item],
					requester_stop,
					requester.inventory,
					request_thresh,
					item,
					qty,
					requester.priority
				)
			end
		end
		request_qty = request_qty - qty
		if request_qty <= 0 then break end
	end
end

---@param item SignalKey
function LogisticsThread:alloc_item(item)
	---@type Cybersyn.Order[]
	local requesters = self.requesters[item]
	local request_all = self.request_all
	-- Early cull if nobody is interested in this item.
	if
		(not requesters or #requesters == 0)
		and (not request_all or #request_all == 0)
	then
		-- TODO: modify `step_async_loop` to allow us to skip to the next item
		-- without waiting for the next processing frame.
		return
	end

	-- Union requesters if needed
	if request_all and #request_all > 0 then
		requesters = concat(requesters, request_all) --[[@as Cybersyn.Order[] ]]
	end

	-- Sort requesters by descending priority, then by when they have last
	-- received this item, then by how busy they are
	tsort(requesters, function(a, b)
		if a.priority > b.priority then return true end
		if
			(a.last_consumed_tick[item] or 0) < (b.last_consumed_tick[item] or 0)
		then
			return true
		end
		return a.busy_value < b.busy_value
	end)

	-- Allocate to each requesting order
	for _, requester in pairs(requesters) do
		self:alloc_item_to(item, requester)
	end
end

--------------------------------------------------------------------------------
-- Loop core
--------------------------------------------------------------------------------

function LogisticsThread:enter_alloc()
	local avail_items = tlib.shuffle(tlib.keys(self.providers))
	self.allocations = {}
	self.allocs_from = {}
	self:begin_async_loop(
		avail_items,
		math.ceil(mod_settings.work_factor * cs2.PERF_ALLOC_ITEM_WORKLOAD)
	)
end

function LogisticsThread:alloc()
	self:step_async_loop(self.alloc_item, function(x) x:set_state("route") end)
end
