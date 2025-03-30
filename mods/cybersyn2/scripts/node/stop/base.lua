local flib_position = require("__flib__.position")
local mlib = require("__cybersyn2__.lib.math")
local slib = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local node_api = _G.cs2.node_api
local stop_api = _G.cs2.stop_api

local distance_squared = flib_position.distance_squared
local pos_get = mlib.pos_get
local INF = math.huge

---Find the stop associated to the given rail using the rail cache.
---@param rail_entity LuaEntity A *valid* rail.
---@return Cybersyn.TrainStop? #The stop state, if found. For performance reasons, this state is not checked for validity.
function _G.cs2.stop_api.find_stop_from_rail(rail_entity)
	local stop_id = storage.rail_id_to_node_id[rail_entity.unit_number]
	if stop_id then
		return storage.nodes[stop_id] --[[@as Cybersyn.TrainStop?]]
	end
end

---Locate all `LuaEntity`s corresponding to train stops within the given area.
---@param surface LuaSurface
---@param area BoundingBox?
---@param position MapPosition?
---@param radius number?
---@return LuaEntity[]
function _G.cs2.stop_api.find_stop_entities(surface, area, position, radius)
	return surface.find_entities_filtered({
		area = area,
		position = position,
		radius = radius,
		name = "train-stop",
	})
end

---Locate all combinators that could potentially be associated to a stop.
---@param stop_entity LuaEntity A *valid* train stop entity.
---@return LuaEntity[]
function _G.cs2.stop_api.find_associable_combinators(stop_entity)
	local pos_x = stop_entity.position.x
	local pos_y = stop_entity.position.y
	return combinator_api.find_combinator_entities(stop_entity.surface, {
		{ pos_x - 2, pos_y - 2 },
		{ pos_x + 2, pos_y + 2 },
	})
end

---Check if the given node is a valid train stop.
---@param stop Cybersyn.Node?
---@return boolean?
local function is_valid(stop)
	---We know after checking type=stop that this is a stop.
	---@diagnostic disable-next-line: undefined-field
	return stop
		and stop.type == "stop"
		and not stop.is_being_destroyed
		and (stop --[[@as Cybersyn.TrainStop]]).entity
		and (stop --[[@as Cybersyn.TrainStop]]).entity.valid
end
stop_api.is_valid = is_valid

---Given the node id of a train stop, get the stop.
---@param node_id Id?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.TrainStop?
function _G.cs2.stop_api.get_stop(node_id, skip_validation)
	if not node_id then return nil end
	local node = node_api.get_node(node_id, skip_validation)
	if skip_validation then
		return node --[[@as Cybersyn.TrainStop]]
	end
	if is_valid(node) then
		return node --[[@as Cybersyn.TrainStop]]
	end
	return nil
end

---Given the unit number of a train stop entity, get the stop.
---@param unit_number UnitNumber?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.TrainStop?
function _G.cs2.stop_api.get_stop_from_unit_number(
	unit_number,
	skip_validation
)
	return stop_api.get_stop(
		storage.stop_id_to_node_id[unit_number or ""],
		skip_validation
	)
end

---Given a combinator, find the nearby rail or stop that may trigger an
---association.
---@param combinator_entity LuaEntity A *valid* combinator entity.
---@return LuaEntity? stop_entity The closest-to-front train stop within the combinator's association zone.
---@return LuaEntity? rail_entity The closest-to-front straight rail with a train stop within the combinator's association zone.
function _G.cs2.stop_api.find_associable_entities_for_combinator(
	combinator_entity
)
	local pos = combinator_entity.position
	local pos_x, pos_y = pos_get(pos)
	local search_area = {
		{ pos_x - 1.5, pos_y - 1.5 },
		{ pos_x + 1.5, pos_y + 1.5 },
	}
	local stop = nil
	local rail = nil
	local stop_dist = INF
	local rail_dist = INF
	local entities = combinator_entity.surface.find_entities_filtered({
		area = search_area,
		name = {
			"train-stop",
			"straight-rail",
		},
	})
	for _, cur_entity in pairs(entities) do
		if cur_entity.name == "train-stop" then
			local dist = distance_squared(pos, cur_entity.position)
			if dist < stop_dist then
				stop_dist = dist
				stop = cur_entity
			end
		elseif cur_entity.type == "straight-rail" then
			-- Prefer rails with stops, then prefer rails nearer the
			-- front of the combinator.
			if stop_api.find_stop_from_rail(cur_entity) then
				local dist = distance_squared(pos, cur_entity.position)
				if dist < rail_dist then
					rail_dist = dist
					rail = cur_entity
				end
			end
		end
	end
	return stop, rail
end

-- TODO: make these faster as they are called a lot in dispatch

---@param stop Cybersyn.TrainStop
---@param key SignalKey
function _G.cs2.stop_api.get_outbound_threshold(stop, key)
	local thresh = stop.thresholds_out and stop.thresholds_out[key] --[[@as int]]
	if thresh then return thresh end
	if slib.key_is_fluid(key) then
		return stop.threshold_fluid_out or 1
	else
		return stop.threshold_item_out or 1
	end
end

---@param stop Cybersyn.TrainStop
---@param key SignalKey
function _G.cs2.stop_api.get_inbound_threshold(stop, key)
	local thresh = stop.thresholds_in and stop.thresholds_in[key] --[[@as int]]
	if thresh then return thresh end
	if slib.key_is_fluid(key) then
		return stop.threshold_fluid_in or 1
	else
		return stop.threshold_item_in or 1
	end
end
