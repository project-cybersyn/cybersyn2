--------------------------------------------------------------------------------
-- Station combinator.
--------------------------------------------------------------------------------

local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local log = require("__cybersyn2__.lib.logging")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local combinator_settings = _G.cs2.combinator_settings

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local If = ultros.If

--------------------------------------------------------------------------------
-- Station combinator settings.
--------------------------------------------------------------------------------

-- Name of the network virtual signal.
combinator_api.register_setting(
	combinator_api.make_raw_setting("network_signal", "network")
)
-- Whether the station should provide, request, or both. Encoded as an integer 0, 1, or 2.
combinator_api.register_setting(combinator_api.make_raw_setting("pr", "pr"))
combinator_api.register_setting(
	combinator_api.make_raw_setting(
		"allow_departure_signal",
		"allow_departure_signal"
	)
)
combinator_api.register_setting(
	combinator_api.make_raw_setting(
		"force_departure_signal",
		"force_departure_signal"
	)
)
combinator_api.register_setting(
	combinator_api.make_raw_setting("inactivity_mode", "inactivity_mode")
)
combinator_api.register_setting(
	combinator_api.make_raw_setting("inactivity_timeout", "inactivity_timeout")
)

combinator_api.register_setting(
	combinator_api.make_flag_setting("use_stack_thresholds", "station_flags", 0)
)
combinator_api.register_setting(
	combinator_api.make_flag_setting(
		"disable_cargo_condition",
		"station_flags",
		1
	)
)

-- TODO: factor out
local function NetworkSignalPicker(combinator, setting)
	return ultros.SignalPicker({
		virtual_signal = combinator_api.read_setting(combinator, setting),
		on_change = function(_, signal, elem)
			if not signal then
				return combinator_api.write_setting(combinator, setting, nil)
			end
			if
				signal.type == "virtual"
				and not cs2.CONFIGURATION_VIRTUAL_SIGNAL_SET[signal.name]
			then
				local stored = signal.name
				if
					signal.name == "signal-everything"
					or signal.name == "signal-anything"
					or signal.name == "signal-each"
				then
					stored = "signal-each"
				end

				combinator_api.write_setting(combinator, setting, stored)
			else
				game.print(
					"Invalid signal type. Please select a non-configuration virtual signal.",
					{
						color = { 255, 128, 0 },
						skip = defines.print_skip.never,
						sound = defines.print_sound.always,
					}
				)
				elem.elem_value = nil
			end
		end,
	})
end

local function AnySignalPicker(combinator, setting)
	return ultros.SignalPicker({
		value = combinator_api.read_setting(combinator, setting),
		on_change = function(_, signal)
			if signal and signal.type == nil then
				signal.type = "item"
			end
			combinator_api.write_setting(combinator, setting, signal)
		end,
	})
end

local function Checkbox(caption, combinator, setting, inverse)
	local value = combinator_api.read_setting(combinator, setting)
	if inverse then
		value = not value
	end
	return ultros.Checkbox({
		caption = caption,
		value = value,
		on_change = function(_, state)
			local new_state = state
			if inverse then
				new_state = not state
			end
			combinator_api.write_setting(combinator, setting, new_state)
		end,
	})
end

relm.define_element({
	name = "CombinatorGui.Mode.Station",
	render = function(props)
		return VF({
			ultros.WellSection({ caption = "Settings" }, {
				ultros.Labeled({ caption = "Cargo", top_margin = 6 }, {
					Pr({
						type = "switch",
						allow_none_state = true,
						switch_state = "none",
						left_label_caption = "Outbound only",
						right_label_caption = "Inbound only",
					}),
				}),
				ultros.Labeled(
					{ caption = { "cybersyn2-gui.network" }, top_margin = 6 },
					{
						NetworkSignalPicker(
							props.combinator,
							combinator_settings.network_signal
						),
					}
				),
				If(
					combinator_api.read_setting(
						props.combinator,
						combinator_settings.network_signal
					) == nil,
					Pr({
						type = "label",
						single_line = false,
						rich_text_setting = defines.rich_text_setting.enabled,
						caption = "[font=default-bold]Warning:[/font] No network signal selected.",
					})
				),
				Pr({
					type = "label",
					font_color = { 255, 230, 192 },
					top_margin = 6,
					font = "default-bold",
					caption = "Flags",
				}),
				Checkbox(
					"Use stack thresholds",
					props.combinator,
					combinator_settings.use_stack_thresholds
				),
			}),
			ultros.WellFold({ caption = "Advanced" }, {
				ultros.Labeled(
					{ caption = "Signal: Allow departure", top_margin = 6 },
					{
						AnySignalPicker(
							props.combinator,
							combinator_settings.allow_departure_signal
						),
					}
				),
				ultros.Labeled(
					{ caption = "Signal: Force departure", top_margin = 6 },
					{
						AnySignalPicker(
							props.combinator,
							combinator_settings.force_departure_signal
						),
					}
				),
				ultros.Labeled({ caption = "Inactivity mode", top_margin = 6 }, {
					Pr({
						type = "switch",
						allow_none_state = true,
						switch_state = "left",
						left_label_caption = "After delivery",
						right_label_caption = "Force out",
					}),
				}),
				ultros.Labeled(
					{ caption = "Inactivity timeout (sec)", top_margin = 6 },
					{
						Pr({
							type = "textfield",
							text = "5",
							width = 75,
							numeric = true,
							allow_decimal = false,
							allow_negative = false,
						}),
					}
				),
				Pr({
					type = "label",
					font_color = { 255, 230, 192 },
					top_margin = 6,
					font = "default-bold",
					caption = "Flags",
				}),
				Checkbox(
					"Enable cargo condition",
					props.combinator,
					combinator_settings.disable_cargo_condition,
					true
				),
			}),
		})
	end,
	message = function(me, payload, props, state)
		if payload.key == "toggle_advanced" then
			local advanced = state and not state.advanced
			relm.set_state(me, function()
				return { advanced = advanced }
			end)
			return true
		end
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Station.Help",
	render = function(props)
		return VF({
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = "Signal Inputs",
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
				draw_horizontal_line_after_headers = true,
			}, {
				Pr({
					type = "label",
					font = "default-bold",
					caption = "Signal",
				}),
				Pr({
					type = "label",
					font = "default-bold",
					caption = "Effect",
				}),
				Pr({
					type = "label",
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "[item=iron-ore][item=copper-plate]...",
				}),
				Pr({
					type = "label",
					single_line = false,
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "Set station inventory. Positive values indicate available cargo, while negative values indicate requested cargo.",
				}),
				Pr({
					type = "label",
					font = "default-large",
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "[virtual-signal=cybersyn2-priority]",
				}),
				Pr({
					type = "label",
					single_line = false,
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "Set the priority for all items at this station.",
				}),
				Pr({
					type = "label",
					font = "default-large",
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "[virtual-signal=cybersyn2-all-items]",
				}),
				Pr({
					type = "label",
					single_line = false,
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "Set the inbound and outbound delivery threshold for all items at this station.",
				}),
				Pr({
					type = "label",
					font = "default-large",
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "[virtual-signal=cybersyn2-all-fluids]",
				}),
				Pr({
					type = "label",
					single_line = false,
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "Set the inbound and outbound delivery threshold for all fluids at this station.",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Station combinator mode registration.
--------------------------------------------------------------------------------

combinator_api.register_combinator_mode({
	name = "station",
	localized_string = "cybersyn2-gui.station",
	settings_element = "CombinatorGui.Mode.Station",
	help_element = "CombinatorGui.Mode.Station.Help",
})
