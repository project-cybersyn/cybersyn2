local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local combinator_modes = _G.cs2.combinator_modes

local strace = stlib.strace
local ERROR = stlib.ERROR

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
	local pstate = cs2.get_or_create_player_state(player_index)
	pstate.open_combinator = combinator
	pstate.open_combinator_unit_number = combinator.entity.unit_number
	return pstate
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
		if not comb or not comb:is_valid() then
			cs2.lib.close_combinator_gui(state.player_index)
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

---Close the combinator gui for the given player.
---@param player_index PlayerIndex
---@param silent boolean?
function _G.cs2.lib.close_combinator_gui(player_index, silent)
	local player = game.get_player(player_index)
	if not player then return end

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
		strace(
			ERROR,
			"message",
			"couldn't destroy associated gui root, probably invalid relm state now",
			player_index
		)
		gui_root[cs2.WINDOW_NAME].destroy()
	end
	destroy_gui_state(player_index)
end

---Open the combinator gui for a player.
---@param player_index PlayerIndex
---@param combinator Cybersyn.Combinator.Ephemeral
function _G.cs2.lib.open_combinator_gui(player_index, combinator)
	if not combinator:is_valid() then return end
	local player = game.get_player(player_index)
	if not player then return end

	-- Close any existing gui
	cs2.lib.close_combinator_gui(player_index, true)
	-- Create new gui state
	local state = create_gui_state(player_index, combinator)

	local root_id, main_window =
		relm.root_create(player.gui.screen, cs2.WINDOW_NAME, "CombinatorGui", {
			player_index = player_index,
			combinator = combinator,
		})

	if main_window then
		main_window.force_auto_center()
		player.opened = main_window
		state.combinator_gui_root = root_id
	else
		strace(
			ERROR,
			"message",
			"Could not open Combinator GUI",
			player_index,
			combinator
		)
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
		if (not props.combinator) or (not props.combinator:is_valid()) then
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-combinator" } }),
			})
		end
		local desired_mode_name =
			props.combinator:read_setting(combinator_settings.mode)
		local options = tlib.t_map_a(
			combinator_modes,
			function(mode, name)
				return {
					key = name,
					caption = { mode.localized_string },
				}
			end
		)
		return ultros.Dropdown({
			options = options,
			horizontally_stretchable = true,
			value = desired_mode_name,
			on_change = "set_combinator_mode",
		})
	end,
	message = function(me, payload, props)
		if payload.key == "combinator_settings_updated" then
			relm.paint(me)
			return true
		elseif payload.key == "set_combinator_mode" then
			local new_mode = payload.value
			if new_mode then
				props.combinator:write_setting(combinator_settings.mode, new_mode)
			end
			return true
		else
			return false
		end
	end,
})

local ModeSettings = relm.define_element({
	name = "CombinatorGui.ModeSettings",
	render = function(props)
		if (not props.combinator) or (not props.combinator:is_valid()) then
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-combinator" } }),
			})
		end
		local desired_mode_name =
			props.combinator:read_setting(combinator_settings.mode)
		local mode = combinator_modes[desired_mode_name]
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
	message = function(me, payload)
		if payload.key == "combinator_settings_updated" then
			relm.paint(me)
			return true
		else
			return false
		end
	end,
})

local Status = relm.define_element({
	name = "CombinatorGui.StatusArea",
	render = function(props)
		if (not props.combinator) or (not props.combinator:is_valid()) then
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-combinator" } }),
			})
		end
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
		if (not props.combinator) or (not props.combinator:is_valid()) then
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-combinator" } }),
			})
		end
		local desired_mode_name =
			props.combinator:read_setting(combinator_settings.mode)
		local mode = combinator_modes[desired_mode_name]
		if mode and mode.help_element then
			return relm.element(mode.help_element, {
				combinator = props.combinator,
				mode = mode,
			})
		else
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-help" } }),
			})
		end
	end,
	message = function(me, payload)
		if payload.key == "combinator_settings_updated" then
			relm.paint(me)
			return true
		else
			return false
		end
	end,
})

local LeftCol = relm.define_element({
	name = "CombinatorGui.LeftCol",
	render = function(props)
		return Pr({
			type = "frame",
			style = "inside_shallow_frame",
			direction = "vertical",
			vertically_stretchable = true,
			width = 400,
			minimal_height = 400,
		}, {
			Pr({
				type = "scroll-pane",
				direction = "vertical",
				vertically_stretchable = true,
				vertical_scroll_policy = "always",
				horizontal_scroll_policy = "never",
				extra_top_padding_when_activated = 0,
				extra_left_padding_when_activated = 0,
				extra_right_padding_when_activated = 0,
				extra_bottom_padding_when_activated = 0,
			}, {
				ultros.WellSection(
					{ caption = "Mode" },
					{ ModePicker({ combinator = props.combinator }) }
				),
				ModeSettings({ combinator = props.combinator }),
			}),
		})
	end,
})

local RightCol = relm.define_element({
	name = "CombinatorGui.RightCol",
	render = function(props)
		return VF({ width = 250, left_margin = 8, visible = props.visible }, {
			Status({ combinator = props.combinator }),
			Help({ combinator = props.combinator }),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui",
	render = function(props, state)
		local show_info = not not (state or {}).show_info
		return ultros.WindowFrame({
			caption = { "cybersyn2-gui.combinator-name" },
			decoration = function()
				return ultros.SpriteButton({
					style = "frame_action_button",
					sprite = "utility/tip_icon",
					on_click = "toggle_info",
					toggled = show_info,
				})
			end,
		}, {
			HF({
				LeftCol({ combinator = props.combinator }),
				RightCol({ combinator = props.combinator, visible = show_info }),
			}),
		})
	end,
	message = function(me, payload, props)
		if payload.key == "close" then
			cs2.lib.close_combinator_gui(props.player_index)
			return true
		elseif payload.key == "toggle_info" then
			relm.set_state(
				me,
				function(prev) return { show_info = not (prev or {}).show_info } end
			)
			return true
		else
			return false
		end
	end,
	state = function() return { show_info = false } end,
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
