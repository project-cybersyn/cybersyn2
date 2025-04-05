--------------------------------------------------------------------------------
-- Allocation phase
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local threads_api = _G.cs2.threads_api
local logistics_thread = _G.cs2.logistics_thread
local mod_settings = _G.cs2.mod_settings
local node_api = _G.cs2.node_api
local inventory_api = _G.cs2.inventory_api

local strace = stlib.strace
local TRACE = stlib.TRACE
local DEBUG = stlib.DEBUG
local ERROR = stlib.ERROR
local tsort = table.sort
local map = tlib.map
local t_map_a = tlib.t_map_a
local filter = tlib.filter
local min = math.min
local get_item_priority = _G.cs2.node_api.get_item_priority
local is_item_match = _G.cs2.node_api.is_item_match
local get_provide = _G.cs2.node_api.get_provide
local get_pull = _G.cs2.node_api.get_pull
local get_node = node_api.get_node
local add_flow = inventory_api.add_flow

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
---@param data Cybersyn.Internal.LogisticsThreadData
---@return [Cybersyn.Node,int][][]
local function get_descending_prio_groups(data, item, base_key, p_key)
	if data[p_key][item] then return data[p_key][item] end
	local xs = data[base_key] --[[@as table<SignalKey, IdSet>]]
	local x_i = xs[item]
	if not x_i or table_size(x_i) == 0 then return {} end
	local g_i = t_map_a(x_i, function(_, id)
		local node = get_node(id)
		if node then return { node, get_item_priority(node, item) } end
	end)
	tsort(g_i, function(a, b) return a[2] > b[2] end)
	local g = tlib.group_by(g_i, 2)
	data[p_key][item] = g
	return g
end

---@param data Cybersyn.Internal.LogisticsThreadData
---@param from_node Cybersyn.Node
---@param from_inv Cybersyn.Inventory
---@param from_thresh uint
---@param to_node Cybersyn.Node
---@param to_inv Cybersyn.Inventory
---@param to_thresh uint
---@param item SignalKey
---@param qty integer
---@param prio integer
local function alloc(
	data,
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
	add_flow(from_inv, flow, -1)
	add_flow(to_inv, flow, 1)
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
	data.allocations[#data.allocations + 1] = allocation
end

local function in_logistics_set(data, logistics_type, node_id, item)
	local set = data[logistics_type][item]
	return set and set[node_id]
end

local function remove_from_logistics_set(data, logistics_type, node_id, item)
	local set = data[logistics_type][item]
	if set then set[node_id] = nil end
end

--------------------------------------------------------------------------------
-- Puller <- Provider
--------------------------------------------------------------------------------

local function alloc_item_pull_provider(
	data,
	item,
	provider_i,
	puller_i,
	pull_prio
)
	local wanted, puller_in_t, puller_inv = get_pull(puller_i, item)
	if wanted == 0 then
		-- Puller no longer wants anything
		return remove_from_logistics_set(data, "pullers", puller_i.id, item)
	end
	local avail, provider_out_t, provider_inv = get_provide(provider_i, item)
	if avail == 0 then
		-- Provider is no longer providing
		return remove_from_logistics_set(data, "providers", provider_i.id, item)
	end
	if wanted >= provider_out_t and avail >= puller_in_t then
		return alloc(
			data,
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

---@param data Cybersyn.Internal.LogisticsThreadData
---@param node Cybersyn.Node
---@param item SignalKey
local function provider_match(data, node, item)
	---@param np [Cybersyn.Node, integer]
	return function(np)
		return in_logistics_set(data, "providers", np[1].id, item)
			and is_item_match(np[1], node, item)
	end
end

---@param data Cybersyn.Internal.LogisticsThreadData
---@param item SignalKey
---@param puller_i Cybersyn.Node
---@param pull_prio integer
local function alloc_item_pull_providers(data, item, puller_i, pull_prio)
	local groups =
		get_descending_prio_groups(data, item, "providers", "providers_p")
	for i = 1, #groups do
		-- Filter nodes by channel match
		local providers_ip = filter(groups[i], provider_match(data, puller_i, item))
		strace(DEBUG, "alloc", item, "providers_ip", providers_ip)
		if #providers_ip > 0 then
			-- TODO: distance-busy-sort remaining nodes
			tlib.shuffle(providers_ip)
			-- Round-robin pull over providers
			for j = 1, #providers_ip do
				alloc_item_pull_provider(
					data,
					item,
					providers_ip[j][1],
					puller_i,
					pull_prio
				)
				-- If puller is no longer pulling we can unwind the loop
				if not in_logistics_set(data, "pullers", puller_i.id, item) then
					return
				end
			end
		end
	end
end

---@param data Cybersyn.Internal.LogisticsThreadData
---@param item SignalKey
local function alloc_item_pull(data, item)
	local groups = get_descending_prio_groups(data, item, "pullers", "pullers_p")
	for i = 1, #groups do
		-- Generate `random_shuffle(Pullers<I,p>)`
		-- TODO: this is incorrect, should be sort-by-last-serviced
		local pullers_ip = groups[i]
		tlib.shuffle(pullers_ip)
		strace(DEBUG, "alloc", item, "pullers_ip", pullers_ip)
		for j = 1, #pullers_ip do
			local puller_i = pullers_ip[j]
			if in_logistics_set(data, "pullers", puller_i[1].id, item) then
				alloc_item_pull_providers(data, item, puller_i[1], puller_i[2])
			end
		end
	end
end

--------------------------------------------------------------------------------
-- State lifecycle
--------------------------------------------------------------------------------

---@param item SignalKey
---@param data Cybersyn.Internal.LogisticsThreadData
local function alloc_item(item, data) alloc_item_pull(data, item) end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.goto_alloc(data)
	data.allocations = {}
	data.providers_p = {}
	data.pullers_p = {}
	data.cargo = tlib.keys(data.seen_cargo)
	tlib.shuffle(data.cargo)
	data.stride =
		math.ceil(mod_settings.work_factor * cs2.PERF_ALLOC_ITEM_WORKLOAD)
	data.index = 1
	data.iteration = 1
	data.state = "alloc"
end

---@param data Cybersyn.Internal.LogisticsThreadData
local function cleanup_alloc(data) logistics_thread.goto_find_vehicles(data) end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.alloc(data)
	cs2.logistics_thread.stride_loop(
		data,
		data.cargo,
		alloc_item,
		function(data2) cleanup_alloc(data2) end
	)
end
