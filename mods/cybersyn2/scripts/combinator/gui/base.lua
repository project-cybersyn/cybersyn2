local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local tlib = require("lib.core.table")
local stlib = require("lib.core.strace")
local cs2 = _G.cs2
local events = require("lib.core.event")

local combinator_modes = _G.cs2.combinator_modes

local strace = stlib.strace
local ERROR = stlib.ERROR

---@param player_index PlayerIndex
local function destroy_gui_state(player_index)
	local state = storage.players[player_index]
	if state then state.open_combinator = nil end
end

---@param player_index PlayerIndex
---@param combinator Cybersyn.Combinator
local function create_gui_state(player_index, combinator)
	local pstate = cs2.get_or_create_player_state(player_index)
	pstate.open_combinator = combinator
	return pstate
end

---Close the combinator gui for the given player.
---@param player_index PlayerIndex
---@param silent boolean?
function _G.cs2.close_combinator_gui(player_index, silent)
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
---@param combinator Cybersyn.Combinator
function _G.cs2.open_combinator_gui(player_index, combinator)
	local player = game.get_player(player_index)
	if not player then return end

	-- Close any existing gui
	cs2.close_combinator_gui(player_index, true)
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
		if not props.combinator then
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-combinator" } }),
			})
		end
		local desired_mode_name = props.combinator.mode
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
			if new_mode then props.combinator:set_mode(new_mode) end
			return true
		else
			return false
		end
	end,
})

local ModeSettings = relm.define_element({
	name = "CombinatorGui.ModeSettings",
	render = function(props)
		relm_util.use_event("cs2.combinator_settings_changed")
		if not props.combinator then
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-combinator" } }),
			})
		end
		local desired_mode_name = props.combinator.mode
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
	message = function(me, payload, props)
		if
			payload.key == "cs2.combinator_settings_changed"
			and payload[1]
			and props.combinator
			and payload[1].id == props.combinator.id
		then
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
		if not props.combinator then
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-combinator" } }),
			})
		end
		local entity = props.combinator.real_entity
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
		relm_util.use_event("cs2.combinator_settings_changed")
		if not props.combinator then
			return VF({
				Pr({ type = "label", caption = { "cybersyn2-gui.no-combinator" } }),
			})
		end
		local desired_mode_name = props.combinator.mode
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
	message = function(me, payload, props)
		if
			payload.key == "cs2.combinator_settings_changed"
			and payload[1]
			and props.combinator
			and payload[1].id == props.combinator.id
		then
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
			minimal_height = 600,
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
			cs2.close_combinator_gui(props.player_index)
			return true
		elseif payload.key == "toggle_info" then
			local player_state = cs2.get_or_create_player_state(props.player_index)
			if player_state.hide_help then
				player_state.hide_help = false
			else
				player_state.hide_help = true
			end
			local show = not player_state.hide_help
			relm.set_state(me, { show_info = show })
			return true
		else
			return false
		end
	end,
	state = function(props)
		local player_state = cs2.get_player_state(props.player_index)
		if player_state and player_state.hide_help then
			return { show_info = false }
		else
			return { show_info = true }
		end
	end,
})
