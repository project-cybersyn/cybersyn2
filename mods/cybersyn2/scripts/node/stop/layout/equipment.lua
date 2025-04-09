--------------------------------------------------------------------------------
-- Train stop equipment scanning.
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local mlib = require("__cybersyn2__.lib.math")
local flib_bbox = require("__flib__.bounding-box")
local cs2 = _G.cs2

---@class Cybersyn.TrainStop
local TrainStop = _G.cs2.TrainStop
local bbox_contains = mlib.bbox_contains

local rail_types = { "straight-rail", "curved-rail-a", "curved-rail-b" }
local equipment_types_set = {
	inserter = true,
	pump = true,
	["loader-1x1"] = true,
	loader = true,
}
local equipment_types = tlib.t_map_a(
	equipment_types_set,
	function(_, k) return k end
)
local equipment_names_set = {}
local equipment_names = tlib.t_map_a(
	equipment_names_set,
	function(_, k) return k end
)

---Get a list of prototype types of equipment that might be used for loading and unloading at a stop.
---@return string[]
function _G.cs2.lib.get_equipment_types() return equipment_types end

---Check if a string is a type of a piece of equipment that might be used for loading and unloading at a stop.
---@param type string?
function _G.cs2.lib.is_equipment_type(type)
	return equipment_types_set[type or ""] or false
end

---Get a list of prototype names of equipment that might be used for loading and unloading at a stop.
---@return string[]
function _G.cs2.lib.get_equipment_names() return equipment_names end

---Check if a string is the name of a piece of equipment that might be used for loading and unloading at a stop.
---@param name string?
function _G.cs2.lib.is_equipment_name(name)
	return equipment_names_set[name or ""] or false
end

---Determine which TrainStop a loader-1x1 can load to, if any.
---@return Cybersyn.TrainStop?
local function get_loader1x1_loading_stop(loader)
	local position = loader.position
	local direction = loader.direction
	local surface = loader.surface
	-- Grow loader bbox in its facing direction by 1 tile...
	-- TODO: use mlib instead of flib
	local area = flib_bbox.ensure_explicit(flib_bbox.from_position(position))
	if
		direction == defines.direction.east
		or direction == defines.direction.west
	then
		area.left_top.x = area.left_top.x - 1
		area.right_bottom.x = area.right_bottom.x + 1
	else
		area.left_top.y = area.left_top.y - 1
		area.right_bottom.y = area.right_bottom.y + 1
	end
	local rails = surface.find_entities_filtered({
		type = rail_types,
		area = area,
	})
	if rails[1] then return TrainStop.find_stop_from_rail(rails[1]) end
	return nil
end

---Determine if the given 1x1 loader entity could load trains at `stop`.
---@param loader LuaEntity
---@param stop Cybersyn.TrainStop
---@return boolean
local function can_loader1x1_load(loader, stop)
	local loading_stop = get_loader1x1_loading_stop(loader)
	if loading_stop and loading_stop.id == stop.id then return true end
	return false
end

--------------------------------------------------------------------------------
-- Equipment registration.
--------------------------------------------------------------------------------

-- XXX: potential MP desync here, probably avoid doing this
local scan_is_ongoing = false

---Register or unregister a piece of loading equipment for the given stop.
---(If `false` is passed for both `is_fluid` and `is_cargo`, the equipment is unregistered.)
---@param entity LuaEntity A *valid* equipment entity.
---@param pos MapPosition The effective position of the equipment for loading/unloading (for an inserter this may be e.g. the drop position). When unregistering equipment, this value is ignored.
---@param is_cargo boolean Whether the equipment can load/unload cargo.
---@param is_fluid boolean Whether the equipment can load/unload fluid.
---@return boolean #Whether the equipment was registered.
function TrainStop:register_loading_equipment(entity, pos, is_cargo, is_fluid)
	local layout = self:get_layout()
	if not layout then return false end
	local equipment_id = entity.unit_number --[[@as UnitNumber]]
	-- Compute position relative to stop.
	local tile_index =
		math.floor(mlib.bbox_measure_ortho(layout.bbox, layout.direction, pos))
	-- Determine if there is an actual change.
	local changed = false
	local previous_cargo = layout.cargo_loader_map[equipment_id]
	if is_cargo then
		if previous_cargo ~= tile_index then changed = true end
		layout.cargo_loader_map[equipment_id] = tile_index
	else
		if previous_cargo then changed = true end
		layout.cargo_loader_map[equipment_id] = nil
	end

	local previous_fluid = layout.fluid_loader_map[equipment_id]
	if is_fluid then
		if previous_fluid ~= tile_index then changed = true end
		layout.fluid_loader_map[equipment_id] = tile_index
	else
		if previous_fluid then changed = true end
		layout.fluid_loader_map[equipment_id] = nil
	end

	-- Raise change events if not in a batch scan.
	if changed and not scan_is_ongoing then
		cs2.raise_train_stop_equipment_changed(self, layout)
	end

	return changed
end

---@param stop Cybersyn.TrainStop
local function register_equipment_if_applicable(
	equipment,
	stop,
	is_being_destroyed
)
	local layout = stop:get_layout()
	if not layout then return end
	local rail_bbox = layout.rail_bbox
	local stop_bbox = layout.bbox
	if (not rail_bbox) or not stop_bbox then return end
	local register_flag = not is_being_destroyed
	if equipment.type == "inserter" then
		if bbox_contains(rail_bbox, equipment.pickup_position) then
			stop:register_loading_equipment(
				equipment,
				equipment.pickup_position,
				register_flag,
				false
			)
		elseif bbox_contains(rail_bbox, equipment.drop_position) then
			stop:register_loading_equipment(
				equipment,
				equipment.drop_position,
				register_flag,
				false
			)
		else
			stop:register_loading_equipment(
				equipment,
				equipment.position,
				false,
				false
			)
		end
	elseif equipment.type == "pump" then
		if equipment.pump_rail_target then
			local rail = equipment.pump_rail_target
			if rail and bbox_contains(rail_bbox, rail.position) then
				stop:register_loading_equipment(
					equipment,
					equipment.position,
					false,
					register_flag
				)
				return
			end
		end
		-- Fallthrough: remove pump from stop equipment manifest
		stop:register_loading_equipment(equipment, equipment.position, false, false)
	elseif equipment.type == "loader-1x1" then
		if can_loader1x1_load(equipment, stop) then
			stop:register_loading_equipment(
				equipment,
				equipment.position,
				register_flag,
				false
			)
		else
			stop:register_loading_equipment(
				equipment,
				equipment.position,
				false,
				false
			)
		end
	elseif equipment.type == "loader" then
		-- TODO: support 2x1 loaders.
	end
end

--------------------------------------------------------------------------------
-- Equipment scan
--------------------------------------------------------------------------------

---@param stop Cybersyn.TrainStop A *valid* train stop state.
---@param ignored_entity_set UnitNumberSet? A set of equipment entities to ignore.
local function scan_equipment(stop, ignored_entity_set)
	local layout = stop:get_layout()
	if not layout then return end
	local stop_entity = stop.entity --[[@as LuaEntity]]
	local bbox = layout.bbox

	layout.cargo_loader_map = {}
	layout.fluid_loader_map = {}

	scan_is_ongoing = true

	local equipment_by_type = stop_entity.surface.find_entities_filtered({
		area = bbox,
		type = cs2.lib.get_equipment_types(),
	})
	for _, equipment in pairs(equipment_by_type) do
		if
			not ignored_entity_set or not ignored_entity_set[equipment.unit_number]
		then
			register_equipment_if_applicable(equipment, stop, false)
		end
	end

	local equipment_by_name = stop_entity.surface.find_entities_filtered({
		area = bbox,
		name = cs2.lib.get_equipment_names(),
	})
	for _, equipment in pairs(equipment_by_name) do
		if
			not ignored_entity_set or not ignored_entity_set[equipment.unit_number]
		then
			register_equipment_if_applicable(equipment, stop, false)
		end
	end

	scan_is_ongoing = false
	cs2.raise_train_stop_equipment_changed(stop, layout)
end

--------------------------------------------------------------------------------
-- Equipment construct/destroy
--------------------------------------------------------------------------------

---@param equipment LuaEntity
---@param is_being_destroyed boolean?
local function built_or_destroyed_equipment(equipment, is_being_destroyed)
	local surface = equipment.surface
	-- Determine which stop the equipment might affect, then register it
	-- with that stop as appropriate.
	if equipment.type == "inserter" then
		local rails = surface.find_entities_filtered({
			type = rail_types,
			position = equipment.pickup_position,
		})
		if rails[1] then
			local stop = TrainStop.find_stop_from_rail(rails[1])
			if stop then
				register_equipment_if_applicable(equipment, stop, is_being_destroyed)
			end
		end

		rails = surface.find_entities_filtered({
			type = rail_types,
			position = equipment.drop_position,
		})
		if rails[1] then
			local stop = TrainStop.find_stop_from_rail(rails[1])
			if stop then
				register_equipment_if_applicable(equipment, stop, is_being_destroyed)
			end
		end
	elseif equipment.type == "pump" then
		if equipment.pump_rail_target then
			local stop = TrainStop.find_stop_from_rail(equipment.pump_rail_target)
			if stop then
				register_equipment_if_applicable(equipment, stop, is_being_destroyed)
			end
		end
	elseif equipment.type == "loader-1x1" then
		local stop = get_loader1x1_loading_stop(equipment)
		if stop then
			if not is_being_destroyed then
				stop:register_loading_equipment(
					equipment,
					equipment.position,
					true,
					false
				)
			else
				stop:register_loading_equipment(
					equipment,
					equipment.position,
					false,
					false
				)
			end
		end
	elseif equipment.type == "loader" then
		-- TODO: support 2x1 loaders
	end
end

--------------------------------------------------------------------------------
-- Event bindings
--------------------------------------------------------------------------------

-- When a stop's layout is full rebuilt, scan in bulk
cs2.on_train_stop_layout_changed(
	function(stop, layout) scan_equipment(stop) end
)

-- When equipment entities are built or destroyed, update individually
cs2.on_built_equipment(
	function(equipment) built_or_destroyed_equipment(equipment, false) end
)

cs2.on_broken_equipment(
	function(equipment) built_or_destroyed_equipment(equipment, true) end
)

-- Special handling for inserter rotation
cs2.on_entity_repositioned(function(kind, entity)
	if kind ~= "inserter" then return end
	-- Find every stop the inserter could possibly interact with and invoke
	-- registration for each of them, which should correctly detect whether
	-- the inserter belongs there or not.
	local area = flib_bbox.from_dimensions(
		entity.position,
		cs2.LONGEST_INSERTER_REACH,
		cs2.LONGEST_INSERTER_REACH
	)
	local rails = entity.surface.find_entities_filtered({
		type = rail_types,
		area = area,
	})
	if #rails == 0 then return end
	local stops = tlib.map(
		rails,
		function(rail) return TrainStop.find_stop_from_rail(rail) end
	)
	for i = 1, #stops do
		register_equipment_if_applicable(entity, stops[i], false)
	end
end)
