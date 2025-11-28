-- Functions for finding, manipulating, and cataloguing space elevator entities.

local bbox_lib = require("__cybersyn2__.lib.core.math.bbox")
local tlib = require("__cybersyn2__.lib.core.table")
local events = require("__cybersyn2__.lib.core.event")
local scheduler = require("__cybersyn2__.lib.core.scheduler")
local strace = require("__cybersyn2__.lib.core.strace")

local TRAIN_STOP_PROTOTYPE_NAME = "se-space-elevator-train-stop"
local CORE_PROTOTYPE_NAME = "se-space-elevator"
local NAMES = { TRAIN_STOP_PROTOTYPE_NAME, CORE_PROTOTYPE_NAME }
local EMPTY = tlib.EMPTY_STRICT

--------------------------------------------------------------------------------
-- SE API calls
--------------------------------------------------------------------------------

---@alias SeZoneType "star"|"planet"|"moon"|"orbit"|"spaceship"|"asteroid-belt"|"asteroid-field"|"anomaly"
---@alias SeZoneIndex integer a zone index is distinct from a surface index because zone can exist without a physical surface

---@class SeZone The relevant fields of a Space Exploration zone; queried with a remote.call
---@field type SeZoneType
---@field name string -- the display name of the zone
---@field index SeZoneIndex -- the zone's table index
---@field orbit_index SeZoneIndex? -- the zone index of the adjacent orbit
---@field parent_index SeZoneIndex? -- the zone index of the adjacent parent zone
---@field surface_index integer? -- the Factorio surface index of the zone
---@field seed integer? -- the mapgen seed

--- Either the surface.index and zone.type of the opposite surface or nil
--- @return integer? surface_index
--- @return string? zone_type
local function find_opposite_surface(surface_index)
	local zone = remote.call(
		"space-exploration",
		"get_zone_from_surface_index",
		{ surface_index = surface_index }
	) --[[@as SeZone]]
	if zone then
		local opposite_zone_index = (
			(zone.type == "planet" or zone.type == "moon") and zone.orbit_index
		)
			or (zone.type == "orbit" and zone.parent_index)
			or nil
		if opposite_zone_index then
			local opposite_zone = remote.call(
				"space-exploration",
				"get_zone_from_zone_index",
				{ zone_index = opposite_zone_index }
			) --[[@as SeZone]]
			if opposite_zone and opposite_zone.surface_index then -- a zone might not have a surface, yet
				return opposite_zone.surface_index, opposite_zone.type
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Elevator data
--------------------------------------------------------------------------------

---@param elevator CS2.SpaceElevatorPlugin.Elevator
function _G.invalidate_elevator(elevator)
	storage.elevators[elevator.unit_number] = nil
	local surface_elevators = storage.elevators_by_surface[elevator.surface_index]
	if surface_elevators then surface_elevators[elevator.unit_number] = nil end
end

---@param elevator CS2.SpaceElevatorPlugin.Elevator?
function _G.is_elevator_valid(elevator)
	if not elevator then return false end
	if not storage.elevators[elevator.unit_number] then return false end
	if (not elevator.stop) or not elevator.stop.valid then return false end
	if not storage.elevators[elevator.opposite_end.unit_number] then
		return false
	end
	if not elevator.opposite_end.stop or not elevator.opposite_end.stop.valid then
		return false
	end
	return true
end

---Invalidate all elevators that are no longer valid.
function _G.invalidate_all_invalid_elevators()
	for _, elevator in pairs(storage.elevators) do
		if not is_elevator_valid(elevator) then invalidate_elevator(elevator) end
	end
end

---Find space elevator entities at the given position on the given surface.
---@param surface LuaSurface
---@param position MapPosition
---@return LuaEntity? core_entity
---@return LuaEntity? stop_entity
local function find_elevator_entities(surface, position)
	local area = bbox_lib.bbox_around(bbox_lib.bbox_new(), position, 24, 24)
	local entities = surface.find_entities_filtered({
		area = area,
		name = NAMES,
	})
	local core_entity, stop_entity
	for _, entity in pairs(entities) do
		if entity.name == CORE_PROTOTYPE_NAME then
			core_entity = entity
		elseif entity.name == TRAIN_STOP_PROTOTYPE_NAME then
			stop_entity = entity
		end
	end

	return core_entity, stop_entity
end

---Make an Elevator object from the core elevator entity.
---@param core_entity LuaEntity
---@return boolean? was_created
---@return CS2.SpaceElevatorPlugin.Elevator? elevator
local function make_elevator_from_core_entity(core_entity)
	-- If already an elevator, return it
	local existing_elevator = storage.elevators[core_entity.unit_number]
	if is_elevator_valid(existing_elevator) then
		strace.trace(
			"make_elevator_from_core_entity: Elevator already exists: ",
			existing_elevator.unit_number,
			existing_elevator.surface_index,
			existing_elevator.opposite_end.surface_index
		)
		return false, existing_elevator
	end

	-- Query SE for opposite surface
	local opposite_surface_index, opposite_zone_type =
		find_opposite_surface(core_entity.surface_index)
	if not opposite_surface_index then return nil end

	-- Find local side of elevator
	local here_core, here_stop =
		find_elevator_entities(core_entity.surface, core_entity.position)
	if not here_core or not here_stop then return nil end
	assert(here_core == core_entity)

	-- Find opposite side of elevator
	local opposite_surface = game.surfaces[opposite_surface_index]
	if not opposite_surface then return nil end
	local opposite_core, opposite_stop =
		find_elevator_entities(opposite_surface, core_entity.position)
	if not opposite_core or not opposite_stop then return nil end

	---@type CS2.SpaceElevatorPlugin.Elevator
	---@diagnostic disable-next-line: missing-fields
	local here_elevator = {
		unit_number = here_stop.unit_number,
		stop = here_stop,
		surface_index = here_stop.surface_index,
	}
	---@type CS2.SpaceElevatorPlugin.Elevator
	---@diagnostic disable-next-line: missing-fields
	local opposite_elevator = {
		unit_number = opposite_stop.unit_number,
		stop = opposite_stop,
		surface_index = opposite_stop.surface_index,
	}
	here_elevator.opposite_end = opposite_elevator
	opposite_elevator.opposite_end = here_elevator

	-- Register elevators in storage
	storage.elevators[here_elevator.unit_number] = here_elevator
	storage.elevators[opposite_elevator.unit_number] = opposite_elevator
	storage.elevators_by_surface[here_elevator.surface_index] = storage.elevators_by_surface[here_elevator.surface_index]
		or {}
	storage.elevators_by_surface[here_elevator.surface_index][here_elevator.unit_number] =
		here_elevator
	storage.elevators_by_surface[opposite_elevator.surface_index] = storage.elevators_by_surface[opposite_elevator.surface_index]
		or {}
	storage.elevators_by_surface[opposite_elevator.surface_index][opposite_elevator.unit_number] =
		opposite_elevator

	strace.info(
		"make_elevator_from_core_entity: Created elevator ",
		here_elevator.unit_number,
		here_elevator.surface_index,
		" <-> ",
		opposite_elevator.surface_index
	)

	return true, here_elevator
end

--------------------------------------------------------------------------------
-- Elevator recognition
--------------------------------------------------------------------------------

local function on_built_elevator_core(event)
	local entity = event.entity
	if entity.name == CORE_PROTOTYPE_NAME then
		-- Wait several frames for elevator to complete construction
		scheduler.after(2, "check_elevator", entity)
	end
end

scheduler.register_handler("check_elevator", function(task)
	local entity = task.data --[[@as LuaEntity]]
	if (not entity) or not entity.valid then return end
	local created = make_elevator_from_core_entity(entity)
	if created then
		-- Make CS2 retopologize accounting for elevators
		remote.call("cybersyn2", "rebuild_train_topologies")
	end
end)

events.bind("on_built_entity", on_built_elevator_core)
events.bind("on_robot_built_entity", on_built_elevator_core)
events.bind("script_raised_built", on_built_elevator_core)
events.bind("script_raised_revive", on_built_elevator_core)

function _G.recheck_all_elevators()
	invalidate_all_invalid_elevators()

	for _, surface in pairs(game.surfaces) do
		local elevator_cores = surface.find_entities_filtered({
			name = CORE_PROTOTYPE_NAME,
		})
		for _, core_entity in pairs(elevator_cores) do
			make_elevator_from_core_entity(core_entity)
		end
	end

	-- Make CS2 retopologize accounting for elevators
	remote.call("cybersyn2", "rebuild_train_topologies")
end

events.bind("on_startup", function() recheck_all_elevators() end)

commands.add_command(
	"cs2-space-elevators-rebuild",
	"Rebuild all space elevator connections.",
	function() recheck_all_elevators() end
)

commands.add_command(
	"cs2-space-elevators-dump",
	"Print information about known elevators to the console.",
	function()
		for _, elevator in pairs(storage.elevators) do
			local str = {
				"",
				"Elevator ",
				elevator.unit_number,
				": ",
				elevator.stop,
				elevator.surface_index,
				" -> ",
				elevator.opposite_end.surface_index,
			}
			game.print(
				str,
				{ skip = defines.print_skip.never, sound = defines.print_sound.never }
			)
		end
	end
)
