local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local stop_api = _G.cs2.stop_api
local combinator_api = _G.cs2.combinator_api
local inventory_api = _G.cs2.inventory_api
local logistics_thread = _G.cs2.logistics_thread
local mod_settings = _G.cs2.mod_settings

---@param inventory Cybersyn.Inventory
---@param combinator Cybersyn.Combinator
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_station_inventory(inventory, combinator, data)
	local combinator_entity = combinator.entity --[[@as LuaEntity]]
	local stop = stop_api.get_stop(combinator.node_id)
	if not stop then
		return
	end
	-- Don't poll inventories while train is at the stop.
	if stop.entity.get_stopped_train() then
		return
	end
	local signals =
		logistics_thread.get_combinator_signals(data, combinator_entity)
	if signals then
		inventory_api.set_inventory_from_signals(
			inventory,
			signals,
			stop.can_request,
			stop.can_provide,
			true
		)
	end
end

---@param inventory Cybersyn.Inventory
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_inventory(inventory, data)
	-- Attempt to figure out what type of inventory this is by examining
	-- its defining combinator.
	local combinator_id = inventory.combinator_id
	if not combinator_id then
		return
	end
	local combinator = combinator_api.get_combinator(combinator_id)
	if not combinator then
		return
	end
	local mode = combinator_api.read_mode(combinator)
	if mode == "station" then
		poll_station_inventory(inventory, combinator, data)
	end
end

local function transition_to_poll_nodes(data)
	data.inventories = nil

	-- Enumerate nodes to poll.
	-- For the moment, that's just train stops.
	data.nodes = tlib.t_map_a(storage.nodes, function(node)
		if
			node.type == "stop"
			and (node --[[@as Cybersyn.TrainStop]]).entity
			and (node --[[@as Cybersyn.TrainStop]]).entity.valid
		then
			return node
		end
	end)
	data.stride =
		math.ceil(mod_settings.work_factor * cs2.PERF_NODE_POLL_WORKLOAD)
	data.index = 1

	-- Clear economic data
	data.item_network_names = {}
	data.requesters = {}
	data.providers = {}

	data.state = "poll_nodes"
end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.poll_inventories(data)
	-- Poll `stride` number of inventories
	local max_index = math.min(data.index + data.stride, #data.inventories)
	for i = data.index, max_index do
		poll_inventory(data.inventories[i], data)
	end
	-- When done, transition to `poll_stations`
	if max_index >= #data.inventories then
		transition_to_poll_nodes(data)
	else
		data.index = max_index + 1
	end
end
