-- Main entry point. Code here should connect game events to the backplane
-- with minimum necessary filtering. This is the only place in the code
-- allowed to bind to Factorio events. Business logic implemented in
-- separate files should then operate by binding to the event backplane.

local counters = require("__cybersyn2__.lib.counters")
local scheduler = require("__cybersyn2__.lib.scheduler")
local tlib = require("__cybersyn2__.lib.table")
local log = require("__cybersyn2__.lib.logging")

-- Initialize sublibraries
on_init(counters.init, true)
on_init(scheduler.init, true)

-- Core game events
script.on_init(raise_init)
script.on_configuration_changed(raise_configuration_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, handle_runtime_mod_setting_changed)
script.on_nth_tick(nil)
script.on_nth_tick(1, scheduler.tick)

-- LuaTrain-related events
script.on_event(defines.events.on_train_created, raise_luatrain_created)
script.on_event(defines.events.on_train_changed_state, raise_luatrain_changed_state)

-- Entity construction
---@param event EventData.script_raised_built|EventData.script_raised_revive|EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_entity_cloned|EventData.on_space_platform_built_entity
local function on_built(event)
	local entity = event.entity or event.destination
	if not entity or not entity.valid then return end

	if entity.name == "train-stop" then
		raise_built_train_stop(entity)
	elseif entity.type == "straight-rail" or entity.type == "curved-rail-a" or entity.type == "curved-rail-b" then
		raise_built_rail(entity)
	elseif entity.name == "entity-ghost" and combinator_api.is_combinator_name(entity.ghost_name) then
		raise_built_combinator_ghost(entity)
	elseif combinator_api.is_combinator_name(entity.name) then
		raise_built_combinator(storage, entity, event.tags)
	elseif stop_api.is_equipment_type(entity.type) or stop_api.is_equipment_name(entity.name) then
		raise_built_equipment(entity)
	end
end

local filter_built = {
	{ filter = "name", name = "train-stop" },
	{ filter = "type", type = "straight-rail" },
	{ filter = "type", type = "curved-rail-a" },
	{ filter = "type", type = "curved-rail-b" },
}
for _, name in ipairs(combinator_api.get_combinator_names()) do
	table.insert(filter_built, { filter = "name", name = name })
	table.insert(filter_built, { filter = "ghost_name", name = name })
end
for _, type in ipairs(stop_api.get_equipment_types()) do
	table.insert(filter_built, { filter = "type", type = type })
end
for _, name in ipairs(stop_api.get_equipment_names()) do
	table.insert(filter_built, { filter = "name", name = name })
end

script.on_event(defines.events.on_built_entity, on_built, filter_built)
script.on_event(defines.events.on_robot_built_entity, on_built, filter_built)
script.on_event(defines.events.on_space_platform_built_entity, on_built, filter_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_event(defines.events.script_raised_revive, on_built)
script.on_event(defines.events.on_entity_cloned, on_built)

-- Entity reconfiguration
---@param event EventData.on_player_rotated_entity
local function on_repositioned(event)
	local entity = event.entity
	if not entity or not entity.valid then return end

	if entity.type == "inserter" then
		raise_entity_repositioned("inserter", entity)
	elseif combinator_api.is_combinator_name(entity.name) then
		raise_entity_repositioned("combinator", entity)
	end
end

---@param event EventData.on_entity_renamed
local function on_renamed(event)
	if event.entity.name == "train-stop" then
		raise_entity_renamed("train-stop", event.entity)
	end
end

---@param event EventData.on_entity_settings_pasted
local function on_settings_pasted(event)
	local ref = combinator_api.entity_to_ephemeral(event.destination)
	if ref then
		raise_combinator_settings_pasted(ref)
	end
end

---@param event EventData.on_pre_build
local function on_maybe_blueprint_pasted(event)
	local player = game.players[event.player_index]
	if not player.is_cursor_blueprint() then return end
	raise_built_blueprint(player, event)
end

script.on_event(defines.events.on_player_rotated_entity, on_repositioned)
script.on_event(defines.events.on_entity_renamed, on_renamed)
script.on_event(defines.events.on_entity_settings_pasted, on_settings_pasted)
script.on_event(defines.events.on_pre_build, on_maybe_blueprint_pasted)

-- Entity destruction
---@param event EventData.on_entity_died|EventData.on_pre_player_mined_item|EventData.on_robot_pre_mined|EventData.on_space_platform_pre_mined|EventData.script_raised_destroy
local function on_destroyed(event)
	local entity = event.entity
	if not entity or not entity.valid then return end

	if entity.name == "train-stop" then
		raise_broken_train_stop(entity)
	elseif entity.type == "straight-rail" or entity.type == "curved-rail-a" or entity.type == "curved-rail-b" then
		raise_broken_rail(entity)
	elseif entity.name == "entity-ghost" and combinator_api.is_combinator_name(entity.ghost_name) then
		raise_broken_combinator_ghost(entity)
	elseif combinator_api.is_combinator_name(entity.name) then
		raise_broken_combinator(storage, entity)
	elseif stop_api.is_equipment_type(entity.type) or stop_api.is_equipment_name(entity.name) then
		raise_broken_equipment(entity)
	elseif entity.train then
		-- Rolling stock.
		raise_broken_train_stock(entity, entity.train)
	end
end

local filter_broken = tlib.assign({}, filter_built)
table.insert(filter_broken, { filter = "rolling-stock" })

script.on_event(defines.events.on_entity_died, on_destroyed, filter_broken)
script.on_event(defines.events.on_pre_player_mined_item, on_destroyed, filter_broken)
script.on_event(defines.events.on_robot_pre_mined, on_destroyed, filter_broken)
script.on_event(defines.events.on_space_platform_pre_mined, on_destroyed, filter_broken)
script.on_event(defines.events.script_raised_destroy, on_destroyed)

-- Surface-related
---@param event EventData.on_pre_surface_cleared|EventData.on_pre_surface_deleted
local function on_surface_removed(event)
	raise_surface_removed(event.surface_index)
end

script.on_event(defines.events.on_pre_surface_cleared, on_surface_removed)
script.on_event(defines.events.on_pre_surface_deleted, on_surface_removed)
