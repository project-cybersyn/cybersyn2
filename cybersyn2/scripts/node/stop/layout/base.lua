--------------------------------------------------------------------------------
-- Train stop layouts.
--------------------------------------------------------------------------------
local tlib = require("__cybersyn2__.lib.table")

local empty = {}

---@param rail_set UnitNumberSet
local function clear_rail_set_from_storage(rail_set)
	local data = (storage --[[@as Cybersyn.Storage]])
	for rail_id in pairs(rail_set or empty) do
		data.rail_id_to_node_id[rail_id] = nil
	end
end

---@param rail_set UnitNumberSet
---@param node_id Id
local function add_rail_set_to_storage(rail_set, node_id)
	local data = (storage --[[@as Cybersyn.Storage]])
	for rail_id in pairs(rail_set or empty) do
		data.rail_id_to_node_id[rail_id] = node_id
	end
end

---@param layout Cybersyn.TrainStopLayout
local function clear_layout(layout)
	clear_rail_set_from_storage(layout.rail_set)
	layout.rail_set = {}
	layout.cargo_loader_map = {}
	layout.fluid_loader_map = {}
	layout.loading_equipment_pattern = {}

	local stop = stop_api.get_stop(layout.node_id, true)
	if stop then
		raise_train_stop_layout_changed(stop)
		local combs = tlib.t_map_a(stop.combinator_set, function(_, combinator_id)
			return combinator_api.get_combinator(combinator_id, true)
		end)
		stop_api.reassociate_combinators(combs)
	end
end
