local class = require("__cybersyn2__.lib.class").class
local mlib = require("__cybersyn2__.lib.math")
local slib = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local Node = _G.cs2.Node
local Topology = _G.cs2.Topology

local distance_squared = mlib.pos_distsq
local pos_get = mlib.pos_get
local INF = math.huge

---@class Cybersyn.TrainStop
local TrainStop = class("TrainStop", Node)
_G.cs2.TrainStop = TrainStop

---@param stop_entity LuaEntity A *valid* train stop entity.
---@return Cybersyn.TrainStop
function TrainStop.new(stop_entity)
	local stop_id = stop_entity.unit_number
	local topology = Topology.get_train_topology(stop_entity.surface_index)
	local node = Node.new("stop") --[[@as Cybersyn.TrainStop]]
	setmetatable(node, TrainStop)
	node.topology_id = topology and topology.id or nil
	node.entity = stop_entity
	node.entity_id = stop_id
	node.allowed_groups = {}
	node.allowed_layouts = {}
	cs2.raise_node_created(node)
	return node
end

---Find the stop associated to the given rail using the rail cache.
---@param rail_entity LuaEntity A *valid* rail.
---@return Cybersyn.TrainStop? #The stop state, if found. For performance reasons, this state is not checked for validity.
function TrainStop.find_stop_from_rail(rail_entity)
	local stop_id = storage.rail_id_to_node_id[rail_entity.unit_number]
	if stop_id then
		return storage.nodes[stop_id] --[[@as Cybersyn.TrainStop?]]
	end
end

---Check if this is a valid train stop.
function TrainStop:is_valid()
	return not self.is_being_destroyed and self.entity and self.entity.valid
end

---Determine if a stop accepts the given layout ID.
---@param layout_id uint?
function TrainStop:accepts_layout(layout_id)
	if not layout_id then return false end
	return self.allowed_layouts and self.allowed_layouts[layout_id]
end

---Determine if a train is allowed at this stop.
---@param train Cybersyn.Train A *valid* train.
function TrainStop:allows_train(train)
	local layout_id = train.layout_id
	if not layout_id then return false end
	return self.allowed_layouts and self.allowed_layouts[layout_id]
	-- TODO: allowed groups
end

---Given the unit number of a train stop entity, get the stop.
---@param unit_number UnitNumber?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.TrainStop?
function TrainStop.get_stop_from_unit_number(unit_number, skip_validation)
	return Node.get(
		storage.stop_id_to_node_id[unit_number or ""],
		skip_validation
	) --[[@as Cybersyn.TrainStop?]]
end

---Locate all `LuaEntity`s corresponding to train stops within the given area.
---@param surface LuaSurface
---@param area BoundingBox?
---@param position MapPosition?
---@param radius number?
---@return LuaEntity[]
function _G.cs2.lib.find_stop_entities(surface, area, position, radius)
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
function _G.cs2.lib.find_associable_combinators(stop_entity)
	local pos_x = stop_entity.position.x
	local pos_y = stop_entity.position.y
	return cs2.lib.find_combinator_entities(stop_entity.surface, {
		{ pos_x - 2, pos_y - 2 },
		{ pos_x + 2, pos_y + 2 },
	})
end

---Given a combinator, find the nearby rail or stop that may trigger an
---association.
---@param combinator_entity LuaEntity A *valid* combinator entity.
---@return LuaEntity? stop_entity The closest-to-front train stop within the combinator's association zone.
---@return LuaEntity? rail_entity The closest-to-front straight rail with a train stop within the combinator's association zone.
function _G.cs2.lib.find_associable_entities_for_combinator(combinator_entity)
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
			if TrainStop.find_stop_from_rail(cur_entity) then
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
