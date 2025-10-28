--------------------------------------------------------------------------------
-- Main entry point
--------------------------------------------------------------------------------

local mgr = _G.mgr
local events = require("__cybersyn2__.lib.core.event")

--------------------------------------------------------------------------------
-- Core Factorio control phase
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- User Inputs
--------------------------------------------------------------------------------

events.bind(defines.events.on_player_selected_area, function(event)
	---@cast event EventData.on_player_selected_area
	local player = game.get_player(event.player_index)
	if not player then return end
	local cursor_stack = player.cursor_stack
	if
		not cursor_stack
		or not cursor_stack.valid
		or not cursor_stack.valid_for_read
	then
		return
	end
	if cursor_stack.name ~= "cybersyn2-inspector" then return end
	events.raise("mgr.on_inspector_selected", event)
	player.clear_cursor()
end)

events.bind(
	"cybersyn2-manager-keybind",
	function(event) events.raise("mgr.on_manager_toggle", event.player_index) end
)

events.bind(defines.events.on_lua_shortcut, function(event)
	if event.prototype_name == "cybersyn2-manager-shortcut" then
		events.raise("mgr.on_manager_toggle", event.player_index)
	end
end)

commands.add_command("cs2-manager-reset", nil, function() mgr.raise_init() end)

--------------------------------------------------------------------------------
-- CS2 custom events
--------------------------------------------------------------------------------

events.bind("cybersyn2-view-updated", function(event)
	if not event.id then return end
	events.raise("mgr.on_view_updated", event.id)
end)
