--------------------------------------------------------------------------------
-- Allocation phase
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
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

---Get and cache descending prio groups for a given item/logistic_type
---@param item string
---@param base_key "providers" | "pushers" | "pullers" | "sinks"
---@param p_key "providers_p" | "pushers_p" | "pullers_p" | "sinks_p"
---@return [Cybersyn.Node,int][][]
function LogisticsThread:get_descending_prio_groups(item, base_key, p_key)
	if self[p_key][item] then return self[p_key][item] end
	local xs = self[base_key] --[[@as table<SignalKey, IdSet>]]
	local x_i = xs[item]
	if not x_i or table_size(x_i) == 0 then return {} end
	local g_i = t_map_a(x_i, function(_, id)
		local node = Node.get(id)
		if node then return { node, node:get_item_priority(item) } end
	end)
	tsort(g_i, function(a, b) return a[2] > b[2] end)
	local g = tlib.group_by(g_i, 2)
	self[p_key][item] = g
	return g
end

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
	local flow = { [item] = qty }
	from_inv:add_flow(flow, -1)
	to_inv:add_flow(flow, 1)
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
	}
	strace(DEBUG, "alloc", item, "allocation", allocation)
	self.allocations[#self.allocations + 1] = allocation
end

---@param alloc Cybersyn.Internal.LogisticsAllocation
function LogisticsThread:refund_allocation(alloc)
	local flow = { [alloc.item] = alloc.qty }
	alloc.from_inv:add_flow(flow, 1)
	alloc.to_inv:add_flow(flow, -1)
end

--------------------------------------------------------------------------------
-- Puller <- Provider
--------------------------------------------------------------------------------

---@param puller_i Cybersyn.Node
---@param provider_i Cybersyn.Node
function LogisticsThread:alloc_item_pull_provider(
	item,
	provider_i,
	puller_i,
	pull_prio
)
	local wanted, puller_in_t, puller_inv = puller_i:get_pull(item)
	if wanted == 0 or not puller_inv then
		-- Puller no longer wants anything
		return self:remove_from_logistics_set("pullers", puller_i.id, item)
	end
	local avail, provider_out_t, provider_inv = provider_i:get_provide(item)
	if avail == 0 or not provider_inv then
		-- Provider is no longer providing
		return self:remove_from_logistics_set("providers", provider_i.id, item)
	end
	if wanted >= provider_out_t and avail >= puller_in_t then
		return self:allocate(
			provider_i,
			provider_inv,
			provider_out_t,
			puller_i,
			puller_inv,
			puller_in_t,
			item,
			min(avail, wanted),
			pull_prio
		)
	end
end

---@param data Cybersyn.LogisticsThread
---@param node Cybersyn.Node
---@param item SignalKey
local function provider_match(data, node, item)
	---@param np [Cybersyn.Node, integer]
	return function(np)
		return data:is_in_logistics_set("providers", np[1].id, item)
			and node:is_item_match(np[1], item)
	end
end

---@param item SignalKey
---@param puller_i Cybersyn.Node
---@param pull_prio integer
function LogisticsThread:alloc_item_pull_providers(item, puller_i, pull_prio)
	local groups =
		self:get_descending_prio_groups(item, "providers", "providers_p")
	for i = 1, #groups do
		-- Filter providers. This will check if the provider is still providing
		-- as well as channel and network matches.
		local providers_ip = filter(groups[i], provider_match(self, puller_i, item))
		strace(DEBUG, "alloc", item, "providers_ip", providers_ip)
		if #providers_ip > 0 then
			-- TODO: distance-busy-sort remaining nodes
			tlib.shuffle(providers_ip)
			-- Round-robin pull over providers
			for j = 1, #providers_ip do
				self:alloc_item_pull_provider(
					item,
					providers_ip[j][1],
					puller_i,
					pull_prio
				)
				-- Optimize: If puller is no longer pulling we can unwind the loop
				if not self:is_in_logistics_set("pullers", puller_i.id, item) then
					return
				end
			end
		end
	end
end

---@param item SignalKey
function LogisticsThread:alloc_item_pull(item)
	local groups = self:get_descending_prio_groups(item, "pullers", "pullers_p")
	for i = 1, #groups do
		-- Generate `random_shuffle(Pullers<I,p>)`
		-- TODO: this is incorrect, should be sort-by-last-serviced
		local pullers_ip = groups[i]
		tlib.shuffle(pullers_ip)
		strace(DEBUG, "alloc", item, "pullers_ip", pullers_ip)
		for j = 1, #pullers_ip do
			local puller_i = pullers_ip[j]
			-- Optimize: puller may have been removed as a result of prior allocations
			if self:is_in_logistics_set("pullers", puller_i[1].id, item) then
				self:alloc_item_pull_providers(item, puller_i[1], puller_i[2])
			end
		end
	end
end

---@param item SignalKey
function LogisticsThread:alloc_item(item) self:alloc_item_pull(item) end

function LogisticsThread:enter_alloc()
	self.allocations = {}
	self.providers_p = {}
	self.pullers_p = {}
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
		function(x) x:set_state("find_vehicles") end
	)
end
