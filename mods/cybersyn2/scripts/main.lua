--------------------------------------------------------------------------------
-- Main entry point. Code here should connect game events to the backplane
-- with minimum necessary filtering. This is the only place in the code
-- allowed to bind to Factorio events. Business logic implemented in
-- separate files should then operate by binding to the event backplane.
--------------------------------------------------------------------------------

local counters = require("__cybersyn2__.lib.counters")
local scheduler = require("__cybersyn2__.lib.scheduler")
local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local cs2 = _G.cs2
local stop_api = _G.cs2.stop_api
local combinator_api = _G.cs2.combinator_api

--------------------------------------------------------------------------------
-- Required library event bindings
--------------------------------------------------------------------------------

cs2.on_init(counters.init, true)
cs2.on_init(scheduler.init, true)
cs2.on_init(relm.init, true)

cs2.on_load(relm.on_load)

--------------------------------------------------------------------------------
-- Core Factorio control phase
--------------------------------------------------------------------------------

script.on_init(cs2.raise_init)
script.on_load(cs2.raise_load)
script.on_configuration_changed(cs2.raise_configuration_changed)
script.on_event(
	defines.events.on_runtime_mod_setting_changed,
	cs2.handle_runtime_mod_setting_changed
)
script.on_nth_tick(nil)
script.on_nth_tick(1, scheduler.tick)

--------------------------------------------------------------------------------
-- LuaTrains
--------------------------------------------------------------------------------

script.on_event(defines.events.on_train_created, cs2.raise_luatrain_created)
script.on_event(
	defines.events.on_train_changed_state,
	cs2.raise_luatrain_changed_state
)

--------------------------------------------------------------------------------
-- Entity construction
--------------------------------------------------------------------------------

---@param event EventData.script_raised_built|EventData.script_raised_revive|EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_entity_cloned|EventData.on_space_platform_built_entity
local function on_built(event)
	local entity = event.entity or event.destination
	if not entity or not entity.valid then
		return
	end

	if entity.name == "train-stop" then
		cs2.raise_built_train_stop(entity)
	elseif
		entity.type == "straight-rail"
		or entity.type == "curved-rail-a"
		or entity.type == "curved-rail-b"
	then
		cs2.raise_built_rail(entity)
	elseif entity.name == "entity-ghost" then
		if entity.ghost_name == "cybersyn2-combinator" then
			cs2.raise_built_combinator_ghost(entity)
		elseif entity.ghost_name == "cybersyn2-combinator-settings" then
			cs2.raise_built_combinator_settings_ghost(entity)
		end
	elseif entity.name == "cybersyn2-combinator" then
		cs2.raise_built_combinator(entity, event.tags)
	elseif
		stop_api.is_equipment_type(entity.type)
		or stop_api.is_equipment_name(entity.name)
	then
		cs2.raise_built_equipment(entity)
	end
end

local filter_built = {
	{ filter = "name", name = "train-stop" },
	{ filter = "type", type = "straight-rail" },
	{ filter = "type", type = "curved-rail-a" },
	{ filter = "type", type = "curved-rail-b" },
	{ filter = "name", name = "cybersyn2-combinator" },
	{ filter = "ghost_name", name = "cybersyn2-combinator" },
	{ filter = "ghost_name", name = "cybersyn2-combinator-settings" },
}
for _, type in ipairs(stop_api.get_equipment_types()) do
	table.insert(filter_built, { filter = "type", type = type })
end
for _, name in ipairs(stop_api.get_equipment_names()) do
	table.insert(filter_built, { filter = "name", name = name })
end

script.on_event(defines.events.on_built_entity, on_built, filter_built)
script.on_event(defines.events.on_robot_built_entity, on_built, filter_built)
script.on_event(
	defines.events.on_space_platform_built_entity,
	on_built,
	filter_built
)
script.on_event(defines.events.script_raised_built, on_built)
script.on_event(defines.events.script_raised_revive, on_built)
script.on_event(defines.events.on_entity_cloned, on_built)

--------------------------------------------------------------------------------
-- Entity configuration
--------------------------------------------------------------------------------

---@param event EventData.on_player_rotated_entity
local function on_repositioned(event)
	local entity = event.entity
	if not entity or not entity.valid then
		return
	end

	if entity.type == "inserter" then
		cs2.raise_entity_repositioned("inserter", entity)

		-- Not needed for square-shaped combinators.
		-- TODO: remove when done prototyping combinators.

		-- elseif entity.name == "cybersyn2-combinator" then
		-- 	raise_entity_repositioned("combinator", entity)
	end
end

---@param event EventData.on_entity_renamed
local function on_renamed(event)
	if event.entity.name == "train-stop" then
		cs2.raise_entity_renamed("train-stop", event.entity)
	end
end

---@param event EventData.on_pre_build
local function on_maybe_blueprint_pasted(event)
	local player = game.players[event.player_index]
	if not player.is_cursor_blueprint() then
		return
	end
	cs2.raise_built_blueprint(player, event)
end

script.on_event(defines.events.on_player_rotated_entity, on_repositioned)
script.on_event(defines.events.on_entity_renamed, on_renamed)
script.on_event(defines.events.on_pre_build, on_maybe_blueprint_pasted)
script.on_event(
	defines.events.on_entity_settings_pasted,
	cs2.raise_entity_settings_pasted
)
script.on_event(
	defines.events.on_player_setup_blueprint,
	cs2.raise_blueprint_setup
)

--------------------------------------------------------------------------------
-- Entity destruction
--------------------------------------------------------------------------------

---@param event EventData.on_entity_died|EventData.on_pre_player_mined_item|EventData.on_robot_pre_mined|EventData.on_space_platform_pre_mined|EventData.script_raised_destroy
local function on_destroyed(event)
	local entity = event.entity
	if not entity or not entity.valid then
		return
	end

	if entity.name == "train-stop" then
		cs2.raise_broken_train_stop(entity)
	elseif
		entity.type == "straight-rail"
		or entity.type == "curved-rail-a"
		or entity.type == "curved-rail-b"
	then
		cs2.raise_broken_rail(entity)
	elseif
		entity.name == "entity-ghost"
		and entity.ghost_name == "cybersyn2-combinator"
	then
		cs2.raise_broken_combinator_ghost(entity)
	elseif entity.name == "cybersyn2-combinator" then
		cs2.raise_broken_combinator(entity)
	elseif
		stop_api.is_equipment_type(entity.type)
		or stop_api.is_equipment_name(entity.name)
	then
		cs2.raise_broken_equipment(entity)
	elseif entity.train then
		-- Rolling stock.
		cs2.raise_broken_train_stock(entity, entity.train)
	end
end

local filter_broken = tlib.assign({}, filter_built)
table.insert(filter_broken, { filter = "rolling-stock" })

script.on_event(defines.events.on_entity_died, on_destroyed, filter_broken)
script.on_event(
	defines.events.on_pre_player_mined_item,
	on_destroyed,
	filter_broken
)
script.on_event(defines.events.on_robot_pre_mined, on_destroyed, filter_broken)
script.on_event(
	defines.events.on_space_platform_pre_mined,
	on_destroyed,
	filter_broken
)
script.on_event(defines.events.script_raised_destroy, on_destroyed)

--------------------------------------------------------------------------------
-- Surfaces
--------------------------------------------------------------------------------

script.on_event(defines.events.on_pre_surface_cleared, function(event)
	cs2.raise_surface(event.surface_index, "cleared")
end)
script.on_event(defines.events.on_pre_surface_deleted, function(event)
	cs2.raise_surface(event.surface_index, "deleted")
end)
script.on_event(defines.events.on_surface_created, function(event)
	cs2.raise_surface(event.surface_index, "created")
end)

--------------------------------------------------------------------------------
-- Combinator GUI
--------------------------------------------------------------------------------

relm.install_event_handlers()

script.on_event(defines.events.on_gui_opened, function(event)
	local comb = combinator_api.entity_to_ephemeral(event.entity)
	if not comb then
		return
	end
	combinator_api.open_gui(event.player_index, comb)
end)
script.on_event(defines.events.on_gui_closed, function(event)
	local element = event.element
	if not element or element.name ~= cs2.WINDOW_NAME then
		return
	end
	combinator_api.close_gui(event.player_index)
end)
