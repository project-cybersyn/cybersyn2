local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local tlib = require("__cybersyn2__.lib.table")
local log = require("__cybersyn2__.lib.logging")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local combinator_settings = _G.cs2.combinator_settings

---@param player_index PlayerIndex
local function destroy_gui_state(player_index)
	local state = storage.players[player_index]
	if state then
		state.open_combinator = nil
		state.open_combinator_unit_number = nil
	end
end

---@param player_index PlayerIndex
---@param combinator Cybersyn.Combinator.Ephemeral
local function create_gui_state(player_index, combinator)
	if not storage.players[player_index] then
		storage.players[player_index] = {
			player_index = player_index,
			open_combinator = nil,
			open_combinator_unit_number = nil,
		}
	end
	storage.players[player_index].open_combinator = combinator
	storage.players[player_index].open_combinator_unit_number =
		combinator.entity.unit_number
	return storage.players[player_index]
end

---Run a callback on each player who has an open combinator GUI.
---@param callback fun(state: Cybersyn.PlayerState, relm_root: Relm.Handle?)
local function for_each_open_combinator_gui(callback)
	for _, state in pairs(storage.players) do
		local player = game.get_player(state.player_index)
		if player and state.combinator_gui_root then
			local root = relm.root_handle(state.combinator_gui_root)
			callback(state, root)
		end
	end
end

local function close_guis_with_invalid_combinators()
	for_each_open_combinator_gui(function(state)
		local comb = state.open_combinator
		if not comb or not combinator_api.is_valid(comb) then
			combinator_api.close_gui(state.player_index)
		end
	end)
end

---@param combinator Cybersyn.Combinator.Ephemeral
local function update_guis_referencing_combinator(combinator)
	local unit_number = combinator.entity.unit_number
	for_each_open_combinator_gui(function(state, root)
		if state.open_combinator_unit_number == unit_number then
			relm.msg_broadcast(root, {
				key = "combinator_settings_updated",
				combinator = combinator,
			})
		end
	end)
end

---Determine if a player has the combinator GUI open.
---@param player_index PlayerIndex
---@return boolean
function _G.cs2.combinator_api.is_gui_open(player_index)
	local player = game.get_player(player_index)
	if not player then
		return false
	end
	local state = storage.players[player_index]
	if state and state.combinator_gui_root then
		return true
	else
		return false
	end
end

---Close the combinator gui for the given player.
---@param player_index PlayerIndex
---@param silent boolean?
function _G.cs2.combinator_api.close_gui(player_index, silent)
	local player = game.get_player(player_index)
	if not player then
		return
	end

	-- Try to close the GUI the easy way
	local state = storage.players[player_index]
	if state and state.combinator_gui_root then
		relm.root_destroy(state.combinator_gui_root)
		state.combinator_gui_root = nil
		if not silent then
			player.play_sound({ path = cs2.COMBINATOR_CLOSE_SOUND })
		end
	end

	-- Hard way
	local gui_root = player.gui.screen
	if gui_root[cs2.WINDOW_NAME] then
		log.error(
			"couldn't destroy associated gui root, probably invalid relm state now",
			player_index
		)
		gui_root[cs2.WINDOW_NAME].destroy()
	end
	destroy_gui_state(player_index)
end

---@param player_index PlayerIndex
---@param combinator Cybersyn.Combinator.Ephemeral
function _G.cs2.combinator_api.open_gui(player_index, combinator)
	if not combinator_api.is_valid(combinator) then
		return
	end
	local player = game.get_player(player_index)
	if not player then
		return
	end
	-- Close any existing gui
	combinator_api.close_gui(player_index, true)
	-- Create new gui state
	local state = create_gui_state(player_index, combinator)

	local root_id, main_window =
		relm.root_create(player.gui.screen, "CombinatorGui", {
			player_index = player_index,
			combinator = combinator,
		}, cs2.WINDOW_NAME)

	if main_window then
		main_window.force_auto_center()
		player.opened = main_window
		state.combinator_gui_root = root_id
	else
		log.error("Could not open Combinator GUI", player_index, combinator)
	end
end

--------------------------------------------------------------------------------
-- Relm combinator gui
--------------------------------------------------------------------------------

local HF = ultros.HFlow
local VF = ultros.VFlow
local Pr = relm.Primitive

local ModePicker = relm.define_element({
	name = "CombinatorGui.ModePicker",
	render = function(props)
		local desired_mode_name =
			combinator_api.read_setting(props.combinator, combinator_settings.mode)
		local options = tlib.map(
			combinator_api.get_combinator_mode_list(),
			function(x)
				return {
					key = x,
					caption = { combinator_api.get_combinator_mode(x).localized_string },
				}
			end
		)
		return ultros.Dropdown({
			options = options,
			horizontally_stretchable = true,
			selected_option = desired_mode_name,
			on_change = "set_combinator_mode",
		})
	end,
	message = function(me, payload, props, state)
		if payload.key == "combinator_settings_updated" then
			relm.paint(me)
			return true
		elseif payload.key == "set_combinator_mode" then
			local new_mode = payload.value
			if new_mode then
				combinator_api.write_setting(
					props.combinator,
					combinator_settings.mode,
					new_mode
				)
			end
			return true
		end
	end,
})

local ModeSettings = relm.define_element({
	name = "CombinatorGui.ModeSettings",
	render = function(props)
		local desired_mode_name =
			combinator_api.read_setting(props.combinator, combinator_settings.mode)
		local mode = combinator_api.get_combinator_mode(desired_mode_name)
		if mode and mode.settings_element then
			return relm.element(mode.settings_element, {
				combinator = props.combinator,
				mode = mode,
			})
		else
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-settings" } }),
			})
		end
	end,
	message = function(me, payload, props, state)
		if payload.key == "combinator_settings_updated" then
			relm.paint(me)
			return true
		end
	end,
})

local Status = relm.define_element({
	name = "CombinatorGui.Status",
	render = function(props)
		local entity = props.combinator.entity
		return VF({
			Pr({
				type = "frame",
				name = "preview_frame",
				style = "deep_frame_in_shallow_frame",

				minimal_width = 0,
				horizontally_stretchable = true,
				padding = 0,
			}, {
				Pr({
					type = "entity-preview",
					style = "wide_entity_button",
					entity = entity,
				}),
			}),
			HF({ vertical_align = "center" }, {
				Pr({
					type = "sprite",
					sprite = "utility/status_working",
					style = "status_image",
					stretch_image_to_widget_size = true,
				}),
				Pr({
					type = "label",
					caption = "Working",
				}),
			}),
		})
	end,
})

local Help = relm.define_element({
	name = "CombinatorGui.Help",
	render = function(props)
		local desired_mode_name =
			combinator_api.read_setting(props.combinator, combinator_settings.mode)
		local mode = combinator_api.get_combinator_mode(desired_mode_name)
		if mode and mode.help_element then
			return relm.element(mode.help_element, {
				combinator = props.combinator,
				mode = mode,
			})
		else
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-settings" } }),
			})
		end
	end,
	message = function(me, payload, props, state)
		if payload.key == "combinator_settings_updated" then
			relm.paint(me)
			return true
		end
	end,
})

local LeftCol = relm.define_element({
	name = "CombinatorGui.LeftCol",
	render = function(props)
		return VF({ width = 400, right_padding = 8 }, {
			Pr({ type = "label", style = "heading_2_label", caption = "Mode" }),
			ModePicker({ combinator = props.combinator }),
			Pr({ type = "label", style = "heading_2_label", caption = "Settings" }),
			ModeSettings({ combinator = props.combinator }),
		})
	end,
})

local RightCol = relm.define_element({
	name = "CombinatorGui.RightCol",
	render = function(props)
		return VF({ width = 250, left_padding = 8 }, {
			Status({ combinator = props.combinator }),
			Help({ combinator = props.combinator }),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui",
	render = function(props)
		return ultros.WindowFrame({
			caption = { "cybersyn-gui.combinator-title" },
		}, {
			HF({
				LeftCol({ combinator = props.combinator }),
				RightCol({ combinator = props.combinator }),
			}),
		})
	end,
	message = function(me, payload, props, state)
		if payload.key == "close" then
			combinator_api.close_gui(props.player_index)
			return true
		end
	end,
})

--------------------------------------------------------------------------------
-- Event handling
--------------------------------------------------------------------------------

-- When a combinator ghost revives, close any guis that may be referencing it.
-- (We're doing this every time a combinator is built which is overkill but
-- there doesn't appear to be a precise event for ghost revival.)
cs2.on_built_combinator(close_guis_with_invalid_combinators)

-- Repaint GUIs when a combinator's settings change.
cs2.on_combinator_or_ghost_setting_changed(update_guis_referencing_combinator)
