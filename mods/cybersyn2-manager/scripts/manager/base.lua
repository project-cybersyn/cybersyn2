local strace_lib = require("__cybersyn2__.lib.strace")
local relm = require("__cybersyn2__.lib.relm")
local relm_helpers = require("__cybersyn2__.lib.relm-helpers")
local ultros = require("__cybersyn2__.lib.ultros")
local tlib = require("__cybersyn2__.lib.table")
local siglib = require("__cybersyn2__.lib.signal")
local mgr = _G.mgr

local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local empty = tlib.empty
local ViewWrapper = _G.mgr.ViewWrapper

_G.mgr.manager = {}
_G.mgr.MANAGER_WINDOW_NAME = "cybersyn2-manager"
local manager = _G.mgr.manager

---Get open manager window for given player.
---@return Relm.RootId? root_id Relm root id of open manager
---@return LuaGuiElement? element Factorio element of open manager
function _G.mgr.manager.get(player_index)
	local player = game.get_player(player_index)
	if not player then return end
	return storage.manager_root[player_index],
		player.gui.screen[mgr.MANAGER_WINDOW_NAME]
end

function _G.mgr.manager.close(player_index)
	local id, window = manager.get(player_index)
	if id then relm.root_destroy(id) end
	if window and window.valid then window.destroy() end
	storage.manager_root[player_index] = nil
end

---Open manager for player if not already open.
---@param player_index uint
---@return Relm.RootId? id If a window was opened, the id of the new root.
function _G.mgr.manager.open(player_index)
	local player = game.get_player(player_index)
	if not player then return end
	local screen = player.gui.screen

	if
		(not manager.get(player_index)) and not screen[mgr.MANAGER_WINDOW_NAME]
	then
		local id, elt = relm.root_create(
			screen,
			"CybersynManager",
			"Cybersyn.Manager",
			{ player_index = player_index }
		)
		storage.manager_root[player_index] = id
		if elt then elt.force_auto_center() end
	end
end

mgr.on_manager_toggle(function(player_index)
	if not player_index then return end

	if manager.get(player_index) then
		manager.close(player_index)
	else
		manager.open(player_index)
	end
end)

--------------------------------------------------------------------------------
-- Elements
--------------------------------------------------------------------------------

local InventoryColumn = relm.define_element({
	name = "Cybersyn.Manager.InventoryColumn",
	render = function(props, state)
		local cols = props.column_count or 5
		return VF({
			Pr({
				type = "frame",
				style = "deep_frame_in_shallow_frame",
				direction = "vertical",
			}, {
				Pr({
					type = "frame",
					style = "subheader_frame",
					horizontally_stretchable = true,
					bottom_margin = 4,
				}, {
					Pr({
						type = "label",
						style = "subheader_caption_label",
						caption = props.caption,
					}),
				}),
				Pr({
					type = "scroll-pane",
					width = 40 * cols + 20,
					height = 700,
					vertical_scroll_policy = "always",
					horizontal_scroll_policy = "never",
				}, {
					Pr({ type = "table", column_count = cols, style = "slot_table" }, {
						mgr.SignalCountsButtons({
							signal_counts = props.signal_counts,
							button_style = props.button_style,
						}),
					}),
				}),
			}),
		})
	end,
})

local InventoryTabInternal = relm.define_element({
	name = "Cybersyn.Manager.InventoryTabInternal",
	render = function(props)
		local provided = props.provides or empty
		local needed = props.needed or empty
		local deficit = tlib.filter_table_in_place(
			tlib.vector_sum(1, provided, -1, needed),
			function(_, v) return v < 0 end
		)
		return Pr({
			type = "table",
			vertically_stretchable = true,
			horizontally_stretchable = true,
			column_count = 3,
		}, {
			InventoryColumn({
				caption = "Provided",
				signal_counts = provided,
				column_count = 8,
			}),
			InventoryColumn({
				caption = "Needed",
				signal_counts = needed,
				button_style = "flib_slot_button_yellow",
				column_count = 6,
			}),
			InventoryColumn({
				caption = "Deficit",
				signal_counts = deficit,
				button_style = "flib_slot_button_red",
				column_count = 3,
			}),
		})
	end,
})

local InventoryTab = relm.define_element({
	name = "Cybersyn.Manager.InventoryTab",
	---@param state table
	render = function(props, state)
		local res = remote.call("cybersyn2", "query", { type = "topologies" })
		local options = {}
		for _, top in pairs(res.data or empty) do
			options[#options + 1] = {
				caption = top.name or "(unknown)",
				key = top.id,
			}
		end
		local network_filter = nil
		if state.network_key then network_filter = { [state.network_key] = -1 } end
		local item_filter = nil
		if state.item_signal then
			item_filter = {
				[state.item_signal.name] = true,
			}
		end
		return VF({
			HF({ vertical_align = "center" }, {
				ultros.Label("Topology"),
				ultros.Dropdown({
					value = state.topology_id,
					options = options,
					on_change = "topology_changed",
				}),
				ultros.Label("Network filter"),
				ultros.SignalPicker({
					on_change = "network_filter_changed",
					virtual_signal = state.network_key,
				}),
				ultros.Label("Item filter"),
				ultros.SignalPicker({
					on_change = "item_filter_changed",
					value = state.item_signal,
				}),
			}),
			ViewWrapper({
				filter = {
					type = "net-inventory",
					topology_id = state.topology_id,
					network_filter = network_filter,
					item_filter = item_filter,
				},
				child = InventoryTabInternal({}),
			}),
		})
	end,
	message = function(me, payload, props)
		if payload.key == "topology_changed" then
			relm_helpers.assign_state(me, { topology_id = payload.value })
			return true
		elseif payload.key == "network_filter_changed" then
			if payload.value and payload.value.type == "virtual" then
				relm_helpers.assign_state(me, { network_key = payload.value.name })
			else
				relm_helpers.set_state_key(me, "network_key", nil)
			end
			return true
		elseif payload.key == "item_filter_changed" then
			if siglib.signal_is_cargo(payload.value) then
				relm_helpers.assign_state(me, { item_signal = payload.value })
			else
				relm_helpers.set_state_key(me, "item_signal", nil)
			end
			return true
		else
			return false
		end
	end,
	state = function(initial_props)
		return { topology_id = 1, network_key = nil, item_signal = nil }
	end,
})

local Tabs = relm.define_element({
	name = "Cybersyn.Manager.Tabs",
	render = function(props)
		return ultros.TabbedPane({
			tabs = {
				{
					caption = "Inventory",
					content = ultros.HiddenTabRemover({ content = InventoryTab() }),
				},
			},
		})
	end,
})

relm.define_element({
	name = "Cybersyn.Manager",
	render = function(props)
		return ultros.WindowFrame({
			caption = "Cybersyn 2 Manager",
		}, {
			Pr({
				type = "frame",
				style = "inside_shallow_frame",
				direction = "vertical",
			}, { Tabs() }),
		})
	end,
	message = function(me, payload, props)
		if payload.key == "close" then
			manager.close(props.player_index)
			return true
		end
		return false
	end,
})
