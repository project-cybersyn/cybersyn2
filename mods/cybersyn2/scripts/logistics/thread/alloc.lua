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
local max = math.max
local pos_get = mlib.pos_get
local sqrt = math.sqrt
local key_is_fluid = siglib.key_is_fluid
local key_to_stacksize = siglib.key_to_stacksize
local empty = tlib.empty
local order_provided_qty = cs2.order_provided_qty
local order_requested_qty = cs2.order_requested_qty
local band = bit32.band
local network_match = siglib.network_match_or

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

---@param item SignalKey
---@param requester Cybersyn.Order
---@param is_fluid boolean?
function LogisticsThread:alloc_item_to(item, requester, is_fluid)
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

	-- Compute threshold and quantity for the request.
	-- Complicated by the fact that it could be a "Request-all" order.
	local request_thresh = requester.thresholds_in[item]
		or requester_stop:get_inbound_threshold(item)
	local request_qty
	if requester.request_all_items and not is_fluid then
		local item_stack_capacity = requester.inventory.item_stack_capacity or 0
		local used_item_stack_capacity = requester.inventory:get_used_capacities()
		local remaining_item_capacity = (
			item_stack_capacity - used_item_stack_capacity
		) * (key_to_stacksize(item) or 0)
		request_qty = max(remaining_item_capacity, 0)
	elseif requester.request_all_fluids and is_fluid then
		local fluid_capacity = requester.inventory.fluid_capacity or 0
		local _, used_fluid_capacity = requester.inventory:get_used_capacities()
		local remaining_fluid_capacity = fluid_capacity - used_fluid_capacity
		request_qty = max(remaining_fluid_capacity, 0)
	else
		request_qty = order_requested_qty(requester, item)
	end

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
		local a_prio = a.priority
		local b_prio = b.priority
		if a_prio > b_prio then return true end
		if a_prio < b_prio then return false end
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
	local is_fluid = key_is_fluid(item)
	local request_all = nil
	if is_fluid then
		request_all = self.request_all_fluids
	else
		request_all = self.request_all_items
	end

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
		local a_prio, b_prio = a.priority, b.priority
		if a_prio > b_prio then return true end
		if a_prio < b_prio then return false end
		-- If priorities are equal, sort by last consumed tick
		local a_last = a.last_consumed_tick[item] or 0
		local b_last = b.last_consumed_tick[item] or 0
		if a_last < b_last then return true end
		if a_last > b_last then return false end
		-- If last consumed ticks are equal, sort by busy value
		return a.busy_value < b.busy_value
	end)

	-- Allocate to each requesting order
	for _, requester in pairs(requesters) do
		self:alloc_item_to(item, requester, is_fluid)
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
