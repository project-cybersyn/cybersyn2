local flib_position = require("__flib__.position")
local tlib = require("__cybersyn2__.lib.table")
local mlib = require("__cybersyn2__.lib.math")

local distance_squared = flib_position.distance_squared
local pos_get = mlib.pos_get
local pos_move_ortho = mlib.pos_move_ortho
local INF = math.huge
local NORTH = defines.direction.north
local SOUTH = defines.direction.south

stop_api = {}

---Find the stop associated to the given rail using the rail cache.
---@param rail_entity LuaEntity A *valid* rail.
---@return Cybersyn.TrainStop? #The stop state, if found. For performance reasons, this state is not checked for validity.
function stop_api.find_stop_from_rail(rail_entity)
	---@type Cybersyn.Storage
	local data = storage
	local stop_id = data.rail_id_to_node_id[rail_entity.unit_number]
	if stop_id then return data.nodes[stop_id] --[[@as Cybersyn.TrainStop?]] end
end

---Locate all `LuaEntity`s corresponding to train stops within the given area.
---@param surface LuaSurface
---@param area BoundingBox?
---@param position MapPosition?
---@param radius number?
---@return LuaEntity[]
function stop_api.find_stop_entities(surface, area, position, radius)
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
function stop_api.find_associable_combinators(stop_entity)
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
	return stop and stop.type == "stop" and stop.entity and stop.entity.valid
end
stop_api.is_valid = is_valid

---Given the node id of a train stop, get the stop.
---@param node_id Id?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.TrainStop?
function stop_api.get_stop(node_id, skip_validation)
	if not node_id then return nil end
	local node = node_api.get_node(node_id, skip_validation)
	if skip_validation then return node --[[@as Cybersyn.TrainStop]] end
	if is_valid(node) then return node --[[@as Cybersyn.TrainStop]] end
	return nil
end

---Given the unit number of a train stop entity, get the stop.
---@param unit_number UnitNumber?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.TrainStop?
function stop_api.get_stop_from_unit_number(unit_number, skip_validation)
	return stop_api.get_stop((storage --[[@as Cybersyn.Storage]]).stop_id_to_node_id[unit_number or ""], skip_validation)
end

---Given a combinator, find the nearby rail or stop that may trigger an
---association.
---@param combinator_entity LuaEntity A *valid* combinator entity.
---@return LuaEntity? stop_entity The closest-to-front train stop within the combinator's association zone.
---@return LuaEntity? rail_entity The closest-to-front straight rail with a train stop within the combinator's association zone.
function stop_api.find_associable_entities_for_combinator(combinator_entity)
	local pos_x, pos_y = pos_get(combinator_entity.position)
	-- We need to account for the direction the combinator is facing. If
	-- the combinator would associate ambiguously with multiple stops or rails,
	-- we prefer the one that is closer to the front of the combinator.
	local front = pos_move_ortho(combinator_entity.position, combinator_entity.direction, 1)
	local search_area
	if combinator_entity.direction == NORTH or combinator_entity.direction == SOUTH then
		search_area = {
			{ pos_x - 1.5, pos_y - 2 },
			{ pos_x + 1.5, pos_y + 2 },
		}
	else
		search_area = {
			{ pos_x - 2, pos_y - 1.5 },
			{ pos_x + 2, pos_y + 1.5 },
		}
	end
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
			local dist = distance_squared(front, cur_entity.position)
			if dist < stop_dist then
				stop_dist = dist
				stop = cur_entity
			end
		elseif cur_entity.type == "straight-rail" then
			-- Prefer rails with stops, then prefer rails nearer the
			-- front of the combinator.
			if stop_api.find_stop_from_rail(cur_entity) then
				local dist = distance_squared(front, cur_entity.position)
				if dist < rail_dist then
					rail_dist = dist
					rail = cur_entity
				end
			end
		end
	end
	return stop, rail
end
