--------------------------------------------------------------------------------
-- Reusable library for manipulating Factorio trains, rails, and stops
--------------------------------------------------------------------------------
if ... ~= "__cybersyn2__.lib.trains" then
	return require("__cybersyn2__.lib.trains")
end

local mlib = require("__cybersyn2__.lib.math")

local defines_front = defines.rail_direction.front
local defines_back = defines.rail_direction.back

local connected_rail_fs = {
	rail_direction = defines_front,
	rail_connection_direction = defines.rail_connection_direction.straight,
}
local connected_rail_fl = {
	rail_direction = defines_front,
	rail_connection_direction = defines.rail_connection_direction.left,
}
local connected_rail_fr = {
	rail_direction = defines_front,
	rail_connection_direction = defines.rail_connection_direction.right,
}
local connected_rail_bs = {
	rail_direction = defines_back,
	rail_connection_direction = defines.rail_connection_direction.straight,
}
local connected_rail_bl = {
	rail_direction = defines_back,
	rail_connection_direction = defines.rail_connection_direction.left,
}
local connected_rail_br = {
	rail_direction = defines_back,
	rail_connection_direction = defines.rail_connection_direction.right,
}

local lib = {}

---Opposite of Factorio's `stop.connected_rail`. Finds the stop that a specific
---rail entity is connected to.
---@param rail_entity LuaEntity A *valid* rail entity.
---@return LuaEntity? stop_entity The stop entity for which `connected_rail` is the given rail entity, if it exists.
function lib.get_connected_stop(rail_entity)
	---@type LuaEntity?
	local stop_entity = rail_entity.get_rail_segment_stop(defines_front)
	if not stop_entity then
		stop_entity = rail_entity.get_rail_segment_stop(defines_back)
	end
	if stop_entity then
		local connected_rail = stop_entity.connected_rail
		if
			connected_rail
			and (connected_rail.unit_number == rail_entity.unit_number)
		then
			return stop_entity
		end
	end
end

---Retrieve all rail entities connected to the given rail entity.
---@param rail_entity LuaEntity A *valid* rail entity.
---@return LuaEntity? rail_fs The rail entity connected to the given rail entity in the front-straight direction, if it exists.
---@return LuaEntity? rail_fl The rail entity connected to the given rail entity in the front-left direction, if it exists.
---@return LuaEntity? rail_fr The rail entity connected to the given rail entity in the front-right direction, if it exists.
---@return LuaEntity? rail_bs The rail entity connected to the given rail entity in the back-straight direction, if it exists.
---@return LuaEntity? rail_bl The rail entity connected to the given rail entity in the back-left direction, if it exists.
---@return LuaEntity? rail_br The rail entity connected to the given rail entity in the back-right direction, if it exists.
function lib.get_all_connected_rails(rail_entity)
	local get_connected_rail = rail_entity.get_connected_rail
	return get_connected_rail(connected_rail_fs),
		get_connected_rail(connected_rail_fl),
		get_connected_rail(connected_rail_fr),
		get_connected_rail(connected_rail_bs),
		get_connected_rail(connected_rail_bl),
		get_connected_rail(connected_rail_br)
end

--------------------------------------------------------------------------------
-- Iterative rail search.
--------------------------------------------------------------------------------

---Terminal states of an iterative rail search.
---@enum IterativeRailSearchDisposition
lib.search_disposition = {
	-- Search is running
	RUNNING = 1,
	-- Search stopped because of user check logic
	STOPPED_COMPLETED = 2,
	-- Search stopped because it could not find a next rail
	STOPPED_NO_CONNECTED_RAIL = 3,
	-- Search stopped because it ran out of iterations.
	STOPPED_ITERATION_LIMIT = 4,
}

---Data structure for storing the state of an iterative rail search.
---@class IterativeRailSearchState
---@field public next_connected_rail any The argument to `get_connected_rail` used to iterate along the rails.
---@field public direction defines.direction? Absolute direction of the search in world space; established after 1 iteration.
---@field public rail LuaEntity? The current rail being examined
---@field public segment_rail LuaEntity? The rail defining the current segment being searched.
---@field public changed_segment boolean? `true` if the most recent iteration of the search moved into a new rail segment. Always `true` on the first iteration.
---@field public front_stop LuaEntity? The stop in the rail segment of the current rail corresponding to `defines.front`.
---@field public back_stop LuaEntity? The stop in the rail segment of the current rail corresponding to `defines.back`.
---@field public disposition IterativeRailSearchDisposition? Terminal state of the search.
---@field public result any? The result returned from `check` when the search ends.
---@field public check fun(state: IterativeRailSearchState): boolean, any Perform the logic of this search. If the check returns `true` the search continues, if it returns `false` the search is done with the given result.
---@field public debug boolean? If `true`, draw a debug overlay for this search.

---@param state IterativeRailSearchState
---@return boolean continue Should the search continue?
---@return any? result The result of the search, if it has ended.
local function iterate(state)
	local current_rail = state.rail
	if not current_rail then return false, nil end

	if state.debug then
		local l, t, r, b = mlib.bbox_get(current_rail.bounding_box)
		rendering.draw_rectangle({
			color = { r = 0, g = 1, b = 0, a = 0.5 },
			left_top = { l, t },
			right_bottom = { r, b },
			surface = current_rail.surface,
			time_to_live = 300,
		})
	end

	-- Check if rail begins a new search segment.
	if
		not state.segment_rail
		or (not current_rail.is_rail_in_same_rail_segment_as(state.segment_rail))
	then
		state.segment_rail = current_rail
		state.changed_segment = true
		state.front_stop = current_rail.get_rail_segment_stop(defines_front)
		state.back_stop = current_rail.get_rail_segment_stop(defines_back)
	else
		state.changed_segment = false
	end

	-- Run the user-defined check.
	local cont, result = state.check(state)
	if not cont then
		state.result = result
		state.disposition = lib.search_disposition.STOPPED_COMPLETED
		return false
	end

	-- Iterate to the next rail.
	local next_rail = current_rail.get_connected_rail(state.next_connected_rail)
	if not next_rail then
		state.disposition = lib.search_disposition.STOPPED_NO_CONNECTED_RAIL
		return false
	end
	if not state.direction then
		state.direction = mlib.dir_ortho(current_rail.position, next_rail.position)
	end
	state.rail = next_rail
	return true
end

---Perform an iterative search along rails.
---@param state IterativeRailSearchState Initial state of the search.
---@param max_iterations uint Maximum number of iterations to perform.
function lib.iterative_rail_search(state, max_iterations)
	state.disposition = lib.search_disposition.RUNNING
	local n = 1
	while n <= max_iterations do
		local cont = iterate(state)
		if not cont then return end
		n = n + 1
	end
	state.disposition = lib.search_disposition.STOPPED_ITERATION_LIMIT
end

--------------------------------------------------------------------------------
-- Trains and carriages
--------------------------------------------------------------------------------

---Determine the net capacity of a train car. Returns `0, 0` for entities that
---are not train cars.
---@param carriage LuaEntity A *valid* carriage entity that is a rolling stock in a train.
---@return number item_slot_capacity The number of item slots the carriage can hold.
---@return number fluid_capacity The total amount of fluid the carriage can hold.
function lib.get_carriage_capacity(carriage)
	if
		carriage.type == "cargo-wagon" or carriage.type == "infinity-cargo-wagon"
	then
		local inventory = carriage.get_inventory(defines.inventory.cargo_wagon)
		return #inventory, 0
	elseif carriage.type == "fluid-wagon" then
		local wagon_proto = carriage.prototype
		local cap = wagon_proto.get_fluid_capacity(carriage.quality)
		return 0, cap
	else
		return 0, 0
	end
end

return lib
