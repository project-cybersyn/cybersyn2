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
local min = math.min
local pos_get = mlib.pos_get
local sqrt = math.sqrt
local key_is_fluid = siglib.key_is_fluid
local key_to_stacksize = siglib.key_to_stacksize
local empty = tlib.empty

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

---Get and cache descending prio groups for a given item/logistic_type
---@param item string
---@param base_key "providers" | "pushers" | "pullers" | "sinks"
---@param p_key "providers_p" | "pushers_p" | "pullers_p" | "sinks_p"
---@return [Cybersyn.Node,int][][]
function LogisticsThread:get_descending_prio_groups(item, base_key, p_key)
	-- Check if we have already cached the groups for this item
	if self[p_key][item] then return self[p_key][item] end
	-- Get base logistics set for this item
	local xs = self[base_key] --[[@as table<SignalKey, IdSet>]]
	local x_i = xs[item]
	if not x_i or table_size(x_i) == 0 then return empty end
	-- Map into { node, prio } pairs
	local g_i = t_map_a(x_i, function(_, id)
		local node = Node.get(id)
		if node then return { node, node:get_item_priority(item) } end
	end)
	-- Sort and group by descending prio
	tsort(g_i, function(a, b) return a[2] > b[2] end)
	local g = tlib.group_by(g_i, 2)
	self[p_key][item] = g
	return g
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
	local consumed, consumer_in_t, consumer_inv =
		get_consumption_info(consumer, item)
	if consumed == 0 or not consumer_inv then
		return self:remove_from_logistics_set(
			consumer_logistics_type,
			consumer.id,
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

	local avail, producer_out_t, producer_inv =
		get_production_info(producer, item)
	if avail == 0 or not producer_inv then
		return self:remove_from_logistics_set(
			producer_logistics_type,
			producer.id,
			item
		)
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

---@param data Cybersyn.LogisticsThread
---@param logistics_type string
---@param node Cybersyn.Node
---@param item SignalKey
local function make_from_filter(data, logistics_type, node, item)
	---@param np [Cybersyn.Node, integer]
	return function(np)
		return data:is_in_logistics_set(logistics_type, np[1].id, item)
			and node:is_item_match(np[1], item)
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

---@param self Cybersyn.LogisticsThread
---@param item SignalKey
---@param to_i Cybersyn.Node
---@param to_prio integer
---@param to_set string
---@param from_set string
---@param from_set_p string
---@param from_filter_gen function
---@param from_sort_gen function
local function generic_to_from_allocator(
	self,
	item,
	to_i,
	to_prio,
	to_set,
	from_set,
	from_set_p,
	from_filter_gen,
	from_sort_gen,
	allocator
)
	local groups = self:get_descending_prio_groups(item, from_set, from_set_p)
	local sort_fn = nil
	for i = 1, #groups do
		-- Filter item producers for existence, network, and channel matches.
		local from_ip =
			filter(groups[i], from_filter_gen(self, from_set, to_i, item))
		if #from_ip > 0 then
			-- Sort potential producers
			if not sort_fn then sort_fn = from_sort_gen(to_i) end
			tsort(from_ip, sort_fn)
			-- Consume from sorted producers
			for j = 1, #from_ip do
				local from_j = from_ip[j][1]
				-- Optimize: skip sources that can no longer produce
				if self:is_in_logistics_set(from_set, from_j.id, item) then
					allocator(self, item, from_j, to_i, to_prio)
				end
				-- Optimize: If consumer is no longer consuming we can unwind the loop
				if not self:is_in_logistics_set(to_set, to_i.id, item) then return end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Pull
--------------------------------------------------------------------------------

---@param self Cybersyn.LogisticsThread
---@param puller_i Cybersyn.Node
---@param provider_i Cybersyn.Node
local function alloc_item_pull_provider(
	self,
	item,
	provider_i,
	puller_i,
	pull_prio
)
	return alloc_item_generic(
		self,
		item,
		provider_i,
		"providers",
		puller_i,
		"pullers",
		pull_prio,
		function(node, itm) return node:get_provide(itm) end,
		function(node, itm) return node:get_pull(itm) end
	)
end

---@param self Cybersyn.LogisticsThread
---@param puller_i Cybersyn.Node
---@param producer_i Cybersyn.Node
local function alloc_item_pull_pusher(
	self,
	item,
	producer_i,
	puller_i,
	pull_prio
)
	return alloc_item_generic(
		self,
		item,
		producer_i,
		"pushers",
		puller_i,
		"pullers",
		pull_prio,
		function(node, itm) return node:get_push(itm) end,
		function(node, itm) return node:get_pull(itm) end
	)
end

---@param item SignalKey
---@param puller_i Cybersyn.Node
---@param pull_prio integer
function LogisticsThread:alloc_item_pull_from_pushers(
	item,
	puller_i,
	pull_prio
)
	return generic_to_from_allocator(
		self,
		item,
		puller_i,
		pull_prio,
		"pullers",
		"pushers",
		"pushers_p",
		make_from_filter,
		make_distance_busy_sort_fn,
		alloc_item_pull_pusher
	)
end

---@param item SignalKey
---@param puller_i Cybersyn.Node
---@param pull_prio integer
function LogisticsThread:alloc_item_pull_from_providers(
	item,
	puller_i,
	pull_prio
)
	return generic_to_from_allocator(
		self,
		item,
		puller_i,
		pull_prio,
		"pullers",
		"providers",
		"providers_p",
		make_from_filter,
		make_distance_busy_sort_fn,
		alloc_item_pull_provider
	)
end

---@param item SignalKey
function LogisticsThread:alloc_item_pull(item)
	local groups = self:get_descending_prio_groups(item, "pullers", "pullers_p")
	for i = 1, #groups do
		-- Generate `sort_by_last_serviced(Pullers<I,p>)`
		local pullers_ip = groups[i]
		tsort(
			pullers_ip,
			function(a, b)
				return (a[1].last_consumer_tick or 0) < (b[1].last_consumer_tick or 0)
			end
		)
		for j = 1, #pullers_ip do
			local puller_i = pullers_ip[j]
			local puller_i_node = puller_i[1]
			local puller_i_prio = puller_i[2]
			if self:is_in_logistics_set("pullers", puller_i_node.id, item) then
				self:alloc_item_pull_from_pushers(item, puller_i_node, puller_i_prio)
			end
			if self:is_in_logistics_set("pullers", puller_i_node.id, item) then
				self:alloc_item_pull_from_providers(item, puller_i_node, puller_i_prio)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Push/Sink
--------------------------------------------------------------------------------

---@param self Cybersyn.LogisticsThread
---@param pusher_i Cybersyn.Node
---@param sink_i Cybersyn.Node
local function alloc_item_sink_pusher(self, item, pusher_i, sink_i, sink_prio)
	return alloc_item_generic(
		self,
		item,
		pusher_i,
		"pushers",
		sink_i,
		"sinks",
		sink_prio,
		function(node, itm) return node:get_push(itm) end,
		function(node, itm) return node:get_sink(itm) end
	)
end

function LogisticsThread:alloc_item_sink_pushers(item, sink_i, sink_prio)
	return generic_to_from_allocator(
		self,
		item,
		sink_i,
		sink_prio,
		"sinks",
		"pushers",
		"pushers_p",
		make_from_filter,
		make_distance_busy_sort_fn,
		alloc_item_sink_pusher
	)
end

---@param item SignalKey
function LogisticsThread:alloc_item_sink(item)
	-- TODO: re-evaluate this. It may be the case that pushers should govern the
	-- outer level of the logistics loop here.
	local groups = self:get_descending_prio_groups(item, "sinks", "sinks_p")
	for i = 1, #groups do
		local sinks_ip = groups[i]
		tsort(
			sinks_ip,
			function(a, b)
				return (a[1].last_consumer_tick or 0) < (b[1].last_consumer_tick or 0)
			end
		)
		for j = 1, #sinks_ip do
			local sink_i_node = sinks_ip[j][1]
			local sink_i_prio = sinks_ip[j][2]
			if self:is_in_logistics_set("sinks", sink_i_node.id, item) then
				self:alloc_item_sink_pushers(item, sink_i_node, sink_i_prio)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Dump
--------------------------------------------------------------------------------

---@param data Cybersyn.LogisticsThread
---@param node Cybersyn.Node
---@param item SignalKey
local function make_dump_filter(data, node, item)
	---@param dump Cybersyn.Node
	return function(dump) return node:is_item_match(dump, item) end
end

local function make_dump_sorter(pusher, item)
	local calc = make_distance_busy_score_calculator(pusher)
	---@param a Cybersyn.TrainStop
	---@param b Cybersyn.TrainStop
	return function(a, b)
		local pa, pb = a:get_item_priority(item), b:get_item_priority(item)
		if pa < pb then
			return true
		elseif pb < pa then
			return false
		else
			return calc(a) < calc(b)
		end
	end
end

function LogisticsThread:alloc_item_push_to_dump(item, pusher_i, pusher_i_prio)
	local sort_fn = nil
	local dumps = filter(self.dumps, make_dump_filter(self, pusher_i, item))
	if #dumps > 0 then
		if not sort_fn then sort_fn = make_dump_sorter(pusher_i) end
		tsort(dumps, sort_fn)
		for j = 1, #dumps do
			local dump_j = dumps[j]

			alloc_item_generic(
				self,
				item,
				pusher_i,
				"pushers",
				dump_j,
				"ERROR",
				pusher_i_prio,
				function(node, itm) return node:get_push(itm) end,
				function(node, itm) return node:get_dump(itm) end
			)

			if not self:is_in_logistics_set("pushers", pusher_i.id, item) then
				return
			end
		end
	end
end

function LogisticsThread:alloc_item_dump(item)
	local groups = self:get_descending_prio_groups(item, "pushers", "pushers_p")
	for i = 1, #groups do
		local pushers_ip = groups[i]
		tsort(
			pushers_ip,
			function(a, b)
				return (a[1].last_producer_tick or 0) < (b[1].last_producer_tick or 0)
			end
		)
		for j = 1, #pushers_ip do
			local pusher_i_node = pushers_ip[j][1]
			local pusher_i_prio = pushers_ip[j][2]
			if self:is_in_logistics_set("pushers", pusher_i_node.id, item) then
				self:alloc_item_push_to_dump(item, pusher_i_node, pusher_i_prio)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Loop core
--------------------------------------------------------------------------------

---@param item SignalKey
function LogisticsThread:alloc_item(item)
	self:alloc_item_pull(item)
	self:alloc_item_sink(item)
	self:alloc_item_dump(item)
end

function LogisticsThread:enter_alloc()
	self.allocations = {}
	self.providers_p = {}
	self.pullers_p = {}
	self.pushers_p = {}
	self.sinks_p = {}
	self.cargo = tlib.keys(self.seen_cargo)
	tlib.shuffle(self.cargo)
	self.stride =
		math.ceil(mod_settings.work_factor * cs2.PERF_ALLOC_ITEM_WORKLOAD)
	self.index = 1
	self.iteration = 1
end

function LogisticsThread:alloc()
	self:async_loop(
		self.cargo,
		self.alloc_item,
		function(x) x:set_state("route") end
	)
end
