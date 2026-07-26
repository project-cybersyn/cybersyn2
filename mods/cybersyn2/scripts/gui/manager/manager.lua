local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local tlib = require("lib.core.table")
local InventoryTab = require("scripts.gui.manager.inventory").InventoryTab
local CargoTab = require("scripts.gui.manager.cargo").CargoTab
local DeliveriesTab = require("scripts.gui.manager.deliveries").DeliveriesTab
local NodesTab = require("scripts.gui.manager.nodes").NodesTab
local VehiclesTab = require("scripts.gui.manager.vehicles").VehiclesTab
local ThreadsTab = require("scripts.gui.manager.threads").ThreadsTab

local Pr = relm.Primitive
local EMPTY = tlib.EMPTY

local function noop() end

--------------------------------------------------------------------------------
-- Main window
--------------------------------------------------------------------------------

local Tabs = relm.define(
	"Manager.Tabs",
	---@param props {player_state: Cybersyn.PlayerState, active_topology_id: integer?, set_active_topology_id: fun(id: integer?), cargo: SignalID?, set_cargo: fun(cargo: SignalID?), network: string?, set_network: fun(network: string?)}
	function(props)
		local active_topology_id, set_active_topology_id =
			props.active_topology_id, props.set_active_topology_id
		local cargo, set_cargo = props.cargo, props.set_cargo
		local network, set_network = props.network, props.set_network

		return ultros.TabbedPane({
			style = "relm_tabbed_pane",
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
					caption = { "cybersyn2-manager.deliveries" },
					content = ultros.HiddenTabRemover({
						generate_content = function()
							return DeliveriesTab({
								active_topology_id = active_topology_id,
								set_active_topology_id = set_active_topology_id,
								cargo = cargo,
								set_cargo = set_cargo,
								network = network,
								set_network = set_network,
							})
						end,
					}),
				},
				{
					caption = { "cybersyn2-manager.vehicles" },
					content = ultros.HiddenTabRemover({
						generate_content = function()
							return VehiclesTab({
								active_topology_id = active_topology_id,
								set_active_topology_id = set_active_topology_id,
							})
						end,
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
	---@param props {player_state: Cybersyn.PlayerState, root_id: integer, player_index: integer, default_topology_id: integer?}
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

		-- Shared states
		local active_topology_id, set_active_topology_id =
			relm.use_state(props.default_topology_id)
		local cargo, set_cargo = relm.use_state(nil --[[@as SignalID?]])
		local network, set_network = relm.use_state(nil --[[@as string?]])

		-- Window frame
		return ultros.WindowFrame({
			caption = "Cybersyn 2 Manager",
			width = 1024,
			height = 768,
			on_close = close_me,
			decoration = function()
				return ultros.PinButton({ pinned = pinned, set_pinned = set_pinned })
			end,
		}, {
			Pr({
				type = "frame",
				style = "inside_deep_frame",
				direction = "vertical",
			}, {
				Tabs({
					player_state = player_state,
					active_topology_id = active_topology_id,
					set_active_topology_id = set_active_topology_id,
					cargo = cargo,
					set_cargo = set_cargo,
					network = network,
					set_network = set_network,
				}),
			}),
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

	local tops = cs2.get_topologies_by_surface_index(player.surface_index)
		or EMPTY
	local top = tops[1]

	relm.root_create(
		screen,
		"Cybersyn2Manager",
		"Cybersyn.Manager",
		{ player_state = player_state, default_topology_id = top and top.id }
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
