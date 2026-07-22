local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local InventoryTab = require("scripts.gui.manager.inventory").InventoryTab
local CargoTab = require("scripts.gui.manager.cargo").CargoTab
local NodesTab = require("scripts.gui.manager.nodes").NodesTab
local VehiclesTab = require("scripts.gui.manager.vehicles").VehiclesTab
local ThreadsTab = require("scripts.gui.manager.threads").ThreadsTab

local Pr = relm.Primitive

local function noop() end

--------------------------------------------------------------------------------
-- Main window
--------------------------------------------------------------------------------

local Tabs = relm.define(
	"Manager.Tabs",
	---@param props {player_state: Cybersyn.PlayerState}
	function(props)
		return ultros.TabbedPane({
			horizontally_stretchable = true,
			vertically_stretchable = true,
			tabs = {
				{
					caption = { "cybersyn2-manager.inventory" },
					content = ultros.HiddenTabRemover({
						generate_content = function() return InventoryTab() end,
					}),
				},
				{
					caption = { "cybersyn2-manager.cargo" },
					content = ultros.HiddenTabRemover({
						generate_content = function() return CargoTab() end,
					}),
				},
				{
					caption = { "cybersyn2-manager.nodes" },
					content = ultros.HiddenTabRemover({
						generate_content = function() return NodesTab() end,
					}),
				},
				{
					caption = { "cybersyn2-manager.vehicles" },
					content = ultros.HiddenTabRemover({
						generate_content = function() return VehiclesTab() end,
					}),
				},
				{
					caption = { "cybersyn2-manager.threads" },
					content = ultros.HiddenTabRemover({
						generate_content = function() return ThreadsTab() end,
					}),
				},
			},
		})
	end
)

relm.define(
	"Cybersyn.Manager",
	---@param props {player_state: Cybersyn.PlayerState, root_id: integer, player_index: integer}
	function(props)
		local player_state = props.player_state

		-- Window management
		local root_id, player_index = props.root_id, props.player_index
		local function _close_me() relm.root_destroy(root_id) end
		local pinned, set_pinned = ultros.use_player_opened_pinnable(player_index)
		local close_me = ultros.use_memoized_window_position(
			_close_me,
			function() return player_state and player_state.manager_gui_pos end,
			pinned and noop or function(loc) player_state.manager_gui_pos = loc end,
			function(elt) elt.force_auto_center() end
		)
		ultros.use_close_on_gui_closed(player_index, close_me, pinned)

		-- Window frame
		return ultros.WindowFrame({
			caption = "Cybersyn 2 Manager",
			width = 800,
			height = 600,
			on_close = close_me,
			decoration = function()
				return ultros.PinButton({ pinned = pinned, set_pinned = set_pinned })
			end,
		}, {
			Pr({
				type = "frame",
				style = "inside_shallow_frame",
				direction = "vertical",
			}, { Tabs({ player_state = player_state }) }),
		})
	end
)

--------------------------------------------------------------------------------
-- Open logic
--------------------------------------------------------------------------------

function cs2.open_manager(player_index)
	if not player_index then return end
	local player = game.get_player(player_index)
	if not player then return end
	local player_state = cs2.get_or_create_player_state(player_index)
	if not player_state then return end
	local screen = player.gui.screen
	if screen["Cybersyn2Manager"] then return end

	relm.root_create(
		screen,
		"Cybersyn2Manager",
		"Cybersyn.Manager",
		{ player_state = player_state }
	)
end

events.bind(
	"cybersyn2-manager-keybind",
	function(event) cs2.open_manager(event.player_index) end
)

events.bind(defines.events.on_lua_shortcut, function(event)
	if event.prototype_name == "cybersyn2-manager-shortcut" then
		cs2.open_manager(event.player_index)
	end
end)
