--------------------------------------------------------------------------------
-- Train stop layouts.
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local tlib = require("lib.core.table")
local mlib = require("lib.core.math.bbox")
local trains_lib = require("lib.trains")
local pos_lib = require("lib.core.math.pos")
local stlib = require("lib.core.strace")
local cs2 = _G.cs2
local Combinator = _G.cs2.Combinator
local Node = _G.cs2.Node

local strace = stlib.strace
local ERROR = stlib.ERROR

local FRONT = defines.rail_direction.front
local BACK = defines.rail_direction.back
local STRAIGHT = defines.rail_connection_direction.straight
local LEFT = defines.rail_connection_direction.left
local RIGHT = defines.rail_connection_direction.right

local NORTH = defines.direction.north
local SOUTH = defines.direction.south
local EAST = defines.direction.east
local WEST = defines.direction.west

local STOPPED_NO_CONNECTED_RAIL =
	trains_lib.search_disposition.STOPPED_NO_CONNECTED_RAIL

local empty = {}

---@class Cybersyn.TrainStop
local TrainStop = _G.cs2.TrainStop

---@class Cybersyn.TrainStopLayout
local TrainStopLayout = class("TrainStopLayout")
_G.cs2.TrainStopLayout = TrainStopLayout

function TrainStopLayout.new(node_id)
	storage.stop_layouts[node_id] = setmetatable({
		node_id = node_id,
		bbox = nil,
		rail_bbox = nil,
		direction = nil,
		rail_set = {},
		cargo_loader_map = {},
		fluid_loader_map = {},
		carriage_loading_pattern = {},
	}, TrainStopLayout)
	return storage.stop_layouts[node_id]
end

---Get the train stop layout for a given node id. If this is not a train stop
---or no layout has been computed, returns `nil`.
---@param node_id Id
---@return Cybersyn.TrainStopLayout?
function TrainStopLayout.get(node_id) return storage.stop_layouts[node_id] end

---Get the layout for a stop, if it has been computed. Returns `nil` if no
---layout has been computed.
---@return Cybersyn.TrainStopLayout?
function TrainStop:get_layout() return storage.stop_layouts[self.id] end

---@param node_id Id
function TrainStopLayout.get_or_create(node_id)
	local layout = storage.stop_layouts[node_id]
	if layout then return layout end
	return TrainStopLayout.new(node_id)
end

---@param rail_set UnitNumberSet
local function clear_rail_set_from_storage(rail_set)
	for rail_id in pairs(rail_set or empty) do
		storage.rail_id_to_node_id[rail_id] = nil
	end
end

---@param rail_set UnitNumberSet
---@param node_id Id
local function add_rail_set_to_storage(rail_set, node_id)
	for rail_id in pairs(rail_set or empty) do
		storage.rail_id_to_node_id[rail_id] = node_id
	end
end

function TrainStopLayout:destroy()
	clear_rail_set_from_storage(self.rail_set)
	storage.stop_layouts[self.node_id] = nil
end

---Clear the layout of a train stop
function TrainStopLayout:clear_layout()
	clear_rail_set_from_storage(self.rail_set)
	self.rail_set = {}
	self.cargo_loader_map = {}
	self.fluid_loader_map = {}
	self.carriage_loading_pattern = {}

	local stop = Node.get(self.node_id, true)
	if stop then
		---@cast stop Cybersyn.TrainStop
		cs2.raise_train_stop_layout_changed(stop, self)
		local combs = tlib.t_map_a(
			stop.combinator_set,
			function(_, combinator_id) return cs2.get_combinator(combinator_id, true) end
		)
		cs2.lib.reassociate_combinators(combs)
	end
end

--------------------------------------------------------------------------------
-- Iterative rail search for train stop bounding boxes.
--------------------------------------------------------------------------------

---@class Cybersyn.Internal.StopBboxSearchState: IterativeRailSearchState
---@field public bbox BoundingBox The bounding box being computed.
---@field public rail_set UnitNumberSet The set of rails used to generate the bbox.
---@field public layout_stop LuaEntity The stop entity that the layout is being computed for.
---@field public ignore_set UnitNumberSet? Set of rail/stop entities to ignore when scanning.

---@param this_stop LuaEntity
---@param rail LuaEntity
---@param other_stop LuaEntity?
---@param ignore_set UnitNumberSet?
local function did_hit_other_stop(this_stop, rail, other_stop, ignore_set)
	if (not other_stop) or not rail then return false end
	if other_stop == this_stop then return false end
	if rail ~= other_stop.connected_rail then return false end
	if ignore_set and ignore_set[other_stop.unit_number] then return false end
	return true
end

---Iterative check function to find bbox of a station.
---@param state Cybersyn.Internal.StopBboxSearchState
local function bbox_iterative_check(state)
	local current_rail = state.rail
	if (not current_rail) or (current_rail.type ~= "straight-rail") then
		return false
	end
	if state.ignore_set and state.ignore_set[current_rail.unit_number] then
		return false
	end

	-- TODO: Check for splits in the track here by also evaluating `rail_connection_direction.left/right`. This would be a breaking change as current allowlists scan past splits.

	-- If we reach a stop that isn't our target stop, abort.
	if
		did_hit_other_stop(
			state.layout_stop,
			current_rail,
			state.front_stop,
			state.ignore_set
		)
		or did_hit_other_stop(
			state.layout_stop,
			current_rail,
			state.back_stop,
			state.ignore_set
		)
	then
		return false
	end

	-- Extend the bounding box to include the current rail.
	mlib.bbox_union(state.bbox, current_rail.bounding_box)
	state.rail_set[current_rail.unit_number] = true
	return true
end

--------------------------------------------------------------------------------
-- Main layout computation algorithm
--------------------------------------------------------------------------------

---Recompute the layout of a train stop.
---@param self Cybersyn.TrainStop A train stop state. Will be validated by this method.
---@param ignored_entity_set? UnitNumberSet A set of entities to ignore when scanning for equipment. Used for e.g. equipment that is in the process of being destroyed.
function TrainStop:compute_layout(ignored_entity_set)
	if not self:is_valid() then return end
	local stop_id = self.id
	local stop_entity = self.entity --[[@as LuaEntity]]
	local stop_layout = TrainStopLayout.get_or_create(stop_id)

	local stop_rail = stop_entity.connected_rail
	if stop_rail == nil then
		-- Disconnected station; clear whole layout.
		stop_layout:clear_layout()
		return
	end

	local rail_direction_from_stop
	if stop_entity.connected_rail_direction == FRONT then
		rail_direction_from_stop = BACK
	else
		rail_direction_from_stop = FRONT
	end
	local stop_direction = stop_entity.direction
	local direction_from_stop = pos_lib.dir_opposite(stop_direction)
	local is_vertical = (stop_direction == NORTH or stop_direction == SOUTH)

	-- Iteratively search for the collection of rails that defines the automatic
	-- bounding box of the station.
	---@type Cybersyn.Internal.StopBboxSearchState
	local state = {
		rail = stop_rail,
		next_connected_rail = {
			rail_direction = rail_direction_from_stop,
			rail_connection_direction = STRAIGHT,
		},
		check = bbox_iterative_check,
		bbox = tlib.deep_copy(stop_rail.bounding_box, true),
		layout_stop = stop_entity,
		rail_set = {},
		ignore_set = ignored_entity_set,
	}
	trains_lib.iterative_rail_search(state, cs2.MAX_RAILS_TO_SEARCH)
	local bbox = state.bbox
	local rail_set = state.rail_set

	-- If the search ended on a curve, add 3 tiles of grace, and add the curve
	-- to the rail set.
	if state.disposition == STOPPED_NO_CONNECTED_RAIL and state.rail then
		local curve_left = state.rail.get_connected_rail({
			rail_direction = rail_direction_from_stop,
			rail_connection_direction = LEFT,
		})
		local curve_right = state.rail.get_connected_rail({
			rail_direction = rail_direction_from_stop,
			rail_connection_direction = RIGHT,
		})
		if
			curve_left
			and (
				curve_left.type ~= "curved-rail-a"
				and curve_left.type ~= "curved-rail-b"
			)
		then
			curve_left = nil
		end
		if
			curve_right
			and (
				curve_right.type ~= "curved-rail-a"
				and curve_right.type ~= "curved-rail-b"
			)
		then
			curve_right = nil
		end
		if
			curve_left
			and ignored_entity_set
			and ignored_entity_set[curve_left.unit_number]
		then
			curve_left = nil
		end
		if
			curve_right
			and ignored_entity_set
			and ignored_entity_set[curve_right.unit_number]
		then
			curve_right = nil
		end

		if curve_left or curve_right then
			mlib.bbox_extend_ortho(bbox, direction_from_stop, 3)
			if curve_left then rail_set[curve_left.unit_number] = true end
			if curve_right then rail_set[curve_right.unit_number] = true end
		end
	end

	-- Update the rail set caches.
	-- TODO: do we need bbox_new here??
	stop_layout.rail_bbox = mlib.bbox_round(mlib.bbox_new(bbox))
	clear_rail_set_from_storage(stop_layout.rail_set)
	stop_layout.rail_set = rail_set
	add_rail_set_to_storage(rail_set, stop_id)

	-- Fatten the bbox in the perpendicular direction to account for equipment
	-- alongside the rails.
	local reach = cs2.LONGEST_INSERTER_REACH
	local l, t, r, b = mlib.bbox_get(bbox)
	if is_vertical then
		l = l - reach
		r = r + reach
		mlib.bbox_set(bbox, l, t, r, b)
	else
		t = t - reach
		b = b + reach
		mlib.bbox_set(bbox, l, t, r, b)
	end
	mlib.bbox_round(bbox)
	stop_layout.bbox = bbox
	stop_layout.direction = direction_from_stop

	-- Reassociate combinators. Combinators in the bbox as well as combinators
	-- that were associated but may be outside the new bbox must all be checked.
	local comb_entities =
		cs2.lib.find_combinator_entities(stop_entity.surface, bbox)
	local reassociable_comb_id_set = tlib.t_map_t(
		comb_entities,
		function(_, entity)
			if
				not ignored_entity_set or not ignored_entity_set[entity.unit_number]
			then
				local _, id = remote.call("things", "get_thing_id", entity)
				return id, true
			else
				return nil, nil
			end
		end
	)
	for comb_id in pairs(self.combinator_set) do
		reassociable_comb_id_set[comb_id] = true
	end
	local reassociable_combs = tlib.t_map_a(
		reassociable_comb_id_set,
		function(_, comb_id) return cs2.get_combinator(comb_id) end
	)
	cs2.lib.reassociate_combinators(reassociable_combs)

	-- Since `reassociate_combinators` can cause significant state
	-- changes, check for safety, although this shouldn't ever happen.
	if not self:is_valid() then
		strace(
			ERROR,
			"message",
			"Stop was removed by reassociate_combinators during layout computation. This shouldn't happen."
		)
		return
	end

	cs2.raise_train_stop_layout_changed(self, stop_layout)
end

--------------------------------------------------------------------------------
-- Stop layout trigger events
--------------------------------------------------------------------------------

-- When a train stop is first created, compute its layout.
cs2.on_node_created(function(node)
	if node.type == "stop" then
		---@cast node Cybersyn.TrainStop
		node:compute_layout()
	end
end)

-- When a train stop is destroyed, clear its layout.
cs2.on_node_destroyed(function(node)
	if node.type == "stop" then
		local layout = storage.stop_layouts[node.id]
		if not layout then return end
		layout:destroy()
	end
end)

local find_stop_from_rail = TrainStop.find_stop_from_rail
local get_connected_stop = trains_lib.get_connected_stop
local get_stop_from_unit_number = TrainStop.get_stop_from_unit_number
local get_all_connected_rails = trains_lib.get_all_connected_rails

-- When rails are built, we need to re-evaluate layouts of affected stops.
-- We must be efficient and rely heavily on the rail cache, as building rails
-- is common/spammy.
cs2.on_built_rail(function(rail)
	-- If this is the connected-rail of a stop, we must update that stop's
	-- layout first to populate the rail cache.
	local connected_stop = get_connected_stop(rail)
	local stop_id0
	if connected_stop then
		local connected_stop_state =
			get_stop_from_unit_number(connected_stop.unit_number, true)
		if connected_stop_state then connected_stop_state:compute_layout() end
	end

	-- Update any stop layout whose rail cache contains an adjacent rail.
	local rail1, rail2, rail3, rail4, rail5, rail6 = get_all_connected_rails(rail)
	local stop_id1, stop_id2, stop_id3, stop_id4, stop_id5

	-- This loop is hand-unrolled for performance reasons.
	-- We want to avoid creating Lua garbage here as this is called per rail.
	-- Also avoid any duplicate calls to `compute_layout`.
	if rail1 then
		local stop = find_stop_from_rail(rail1)
		local stop_id = stop and stop.id
		if stop and stop_id ~= stop_id0 then
			stop_id1 = stop_id
			stop:compute_layout()
		end
	end
	if rail2 then
		local stop = find_stop_from_rail(rail2)
		local stop_id = stop and stop.id
		if stop and stop_id ~= stop_id0 and stop_id ~= stop_id1 then
			stop_id2 = stop_id
			stop:compute_layout()
		end
	end
	if rail3 then
		local stop = find_stop_from_rail(rail3)
		local stop_id = stop and stop.id
		if
			stop
			and stop_id ~= stop_id0
			and stop_id ~= stop_id1
			and stop_id ~= stop_id2
		then
			stop_id3 = stop_id
			stop:compute_layout()
		end
	end
	if rail4 then
		local stop = find_stop_from_rail(rail4)
		local stop_id = stop and stop.id
		if
			stop
			and stop_id ~= stop_id0
			and stop_id ~= stop_id1
			and stop_id ~= stop_id2
			and stop_id ~= stop_id3
		then
			stop_id4 = stop_id
			stop:compute_layout()
		end
	end
	if rail5 then
		local stop = find_stop_from_rail(rail5)
		local stop_id = stop and stop.id
		if
			stop
			and stop_id ~= stop_id0
			and stop_id ~= stop_id1
			and stop_id ~= stop_id2
			and stop_id ~= stop_id3
			and stop_id ~= stop_id4
		then
			stop_id5 = stop_id
			stop:compute_layout()
		end
	end
	if rail6 then
		local stop = find_stop_from_rail(rail6)
		local stop_id = stop and stop.id
		if
			stop
			and stop_id ~= stop_id0
			and stop_id ~= stop_id1
			and stop_id ~= stop_id2
			and stop_id ~= stop_id3
			and stop_id ~= stop_id4
			and stop_id ~= stop_id5
		then
			stop:compute_layout()
		end
	end
end)

-- When a rail is being destroyed, we need to re-evaluate layouts of affected stops.
cs2.on_broken_rail(function(rail)
	-- TODO: it is possible that breaking a rail would remove a split in the tracks,
	-- causing a stop that was not associated with that rail to be enlarged. That case requires a more complex
	-- algorithm and isn't handled right now.
	local stop = find_stop_from_rail(rail)
	if stop then stop:compute_layout({ [rail.unit_number] = true }) end
end)

-- When a train stop is built/broken check its attached rail, as well as the rails
-- front and back from it, for other stops. If any are found, we need to
-- recompute the layout of those stops.
---@param stop_entity LuaEntity
---@param is_being_destroyed boolean?
local function recompute_nearby_stop_layouts(stop_entity, is_being_destroyed)
	local r1 = stop_entity.connected_rail
	if not r1 then return end
	local ies = nil
	if is_being_destroyed then ies = { [stop_entity.unit_number] = true } end
	local s0 = get_stop_from_unit_number(stop_entity.unit_number, true)
	local r2, _, _, r3 = get_all_connected_rails(r1)
	local s1, s2, s3 =
		r1 and find_stop_from_rail(r1),
		r2 and find_stop_from_rail(r2),
		r3 and find_stop_from_rail(r3)
	-- Avoid rechecking the same stop multiple times.
	if s1 and ((not s0) or (s1 ~= s0)) then s1:compute_layout(ies) end
	if s2 and ((not s1) or (s2 ~= s1)) and ((not s0) or (s2 ~= s0)) then
		s2:compute_layout(ies)
	end
	if
		s3
		and ((not s2) or (s3 ~= s2))
		and ((not s1) or (s3 ~= s1))
		and ((not s0) or (s3 ~= s0))
	then
		s3:compute_layout(ies)
	end
end

cs2.on_built_train_stop(
	function(stop) recompute_nearby_stop_layouts(stop, false) end
)

cs2.on_broken_train_stop(
	function(stop) recompute_nearby_stop_layouts(stop, true) end
)
