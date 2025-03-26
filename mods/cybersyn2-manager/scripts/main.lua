--------------------------------------------------------------------------------
-- Main entry point. Code here should connect game events to the backplane
-- with minimum necessary filtering. This is the only place in the code
-- allowed to bind to Factorio events. Business logic implemented in
-- separate files should then operate by binding to the event backplane.
--------------------------------------------------------------------------------

local counters = require("__cybersyn2__.lib.counters")
local scheduler = require("__cybersyn2__.lib.scheduler")
local flib_gui = require("__flib__.gui")
local log = require("__cybersyn2__.lib.logging")

local mgr = _G.mgr

--------------------------------------------------------------------------------
-- Library init
--------------------------------------------------------------------------------

mgr.on_init(counters.init, true)
mgr.on_init(scheduler.init, true)

--------------------------------------------------------------------------------
-- Core Factorio control phase
--------------------------------------------------------------------------------

script.on_init(mgr.raise_init)
script.on_configuration_changed(mgr.raise_configuration_changed)
script.on_event(
	defines.events.on_runtime_mod_setting_changed,
	mgr.handle_runtime_mod_setting_changed
)
script.on_nth_tick(nil)
script.on_nth_tick(1, scheduler.tick)

--------------------------------------------------------------------------------
-- User Inputs
--------------------------------------------------------------------------------

script.on_event(defines.events.on_player_selected_area, function(event)
	---@cast event EventData.on_player_selected_area
	local player = game.get_player(event.player_index)
	if not player then
		return
	end
	local cursor_stack = player.cursor_stack
	if
		not cursor_stack
		or not cursor_stack.valid
		or not cursor_stack.valid_for_read
	then
		return
	end
	if cursor_stack.name ~= "cybersyn2-inspector" then
		return
	end

	mgr.raise_inspector_selected(event)
	player.clear_cursor()
end)

script.on_event("cybersyn2-manager-keybind", function(event)
	mgr.raise_manager_toggle(event.player_index)
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
	if event.prototype_name == "cybersyn2-manager-shortcut" then
		mgr.raise_manager_toggle(event.player_index)
	end
end)

--------------------------------------------------------------------------------
-- Gui
--------------------------------------------------------------------------------

flib_gui.handle_events()
