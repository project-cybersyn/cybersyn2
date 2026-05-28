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

local function noop() end

--------------------------------------------------------------------------------
-- Relm combinator gui
--------------------------------------------------------------------------------

local HF = ultros.HFlow
local VF = ultros.VFlow
local Pr = relm.Primitive

local ModePicker = relm.define_element({
	name = "CombinatorGui.ModePicker",
	render = function(props)
		relm_util.use_event("cs2.combinator_settings_changed")
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
		if
			payload.key == "cs2.combinator_settings_changed"
			and payload[1]
			and props.combinator
			and payload[1].id == props.combinator.id
		then
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
		return VF({ width = 400, left_margin = 8, visible = props.visible }, {
			Status({ combinator = props.combinator }),
			Help({ combinator = props.combinator }),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui",
	render = function(props)
		local combinator = props.combinator
		-- Window management
		local root_id, player_index = props.root_id, props.player_index
		local function _close_me()
			local player = game.get_player(player_index)
			local elt = relm.get_root_element(root_id)
			if elt and player and player.opened == elt then player.opened = nil end
			if not relm.root_destroy(root_id) then return end
			if player then
				player.play_sound({ path = cs2.COMBINATOR_CLOSE_SOUND })
			end
			events.raise("cs2.combinator_gui_closed", combinator, player)
		end
		local pinned, set_pinned = ultros.use_player_opened_pinnable(player_index)
		local close_me = ultros.use_memoized_window_position(_close_me, function()
			local player_state = cs2.get_player_state(player_index)
			return player_state and player_state.combinator_gui_pos
		end, pinned and noop or function(loc)
			local player_state = cs2.get_or_create_player_state(player_index)
			player_state.combinator_gui_pos = loc
		end, function(elt) elt.force_auto_center() end)
		ultros.use_close_on_gui_closed(player_index, close_me, pinned)

		-- Show/hide help
		local show_info = true
		local player_state = cs2.get_player_state(player_index)
		if player_state and player_state.hide_help then show_info = false end
		local function toggle_hide_help()
			cs2.update_player_state(player_index, "hide_help", show_info)
		end
		relm_util.use_event_handler(
			"cs2.player_state_updated",
			function(me, _, updated_state)
				if updated_state.player_index == player_index then relm.paint(me) end
			end
		)

		-- Close GUI if combinator is destroyed.
		relm_util.use_event_handler(
			"cs2.combinator_destroyed",
			function(me, _, comb)
				if props.combinator and comb.id == props.combinator.id then
					close_me()
				end
			end
		)

		return ultros.WindowFrame({
			caption = { "cybersyn2-gui.combinator-name" },
			on_close = close_me,
			decoration = {
				ultros.PinButton({ pinned = pinned, set_pinned = set_pinned }),
				ultros.SpriteButton({
					style = "frame_action_button",
					sprite = "utility/tip_icon",
					on_click = toggle_hide_help,
					toggled = show_info,
				}),
			},
		}, {
			HF({
				LeftCol({ combinator = props.combinator }),
				RightCol({ combinator = props.combinator, visible = show_info }),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

if _G.__RECOVERY_MODE__ then return end

events.bind(
	defines.events.on_gui_opened,
	---@param event EventData.on_gui_opened
	function(event)
		if not event.entity then return end
		if not cs2.entity_is_combinator_or_ghost(event.entity) then return end
		local player_index = event.player_index
		local player = game.get_player(player_index)
		if not player then return end

		local _, id = remote.call("things", "get_thing_id", event.entity)
		local comb = cs2.get_combinator(id)
		if not comb then
			player.print(
				"Cybersyn 2: Attempted to open a combinator without an associated state. Run a full reset (or complete an in-progress reset procedure) before proceeding.",
				{
					color = { r = 1, g = 0, b = 0 },
					skip = defines.print_skip.never,
					sound = defines.print_sound.always,
				}
			)
			-- Close the default GUI.
			player.opened = nil
			return
		end

		local root_id, main_window =
			relm.root_create(player.gui.screen, nil, "CombinatorGui", {
				player_index = player_index,
				combinator = comb,
			})

		if main_window then
			events.raise("cs2.combinator_gui_opened", comb, player, root_id)
		else
			strace(
				ERROR,
				"message",
				"Could not open Combinator GUI",
				player_index,
				comb
			)
		end
	end
)
