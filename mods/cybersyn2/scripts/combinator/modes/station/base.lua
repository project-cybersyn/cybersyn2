--------------------------------------------------------------------------------
-- Station combinator.
--------------------------------------------------------------------------------

local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local log = require("__cybersyn2__.lib.logging")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

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

--------------------------------------------------------------------------------
-- Relm gui for station combinator
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Station",
	render = function(props)
		return VF({
			ultros.WellSection({ caption = "Settings" }, {
				ultros.Labeled({ caption = "Cargo", top_margin = 6 }, {
					gui.Switch(
						true,
						"Outbound only",
						"Inbound only",
						props.combinator,
						combinator_settings.pr
					),
				}),
				ultros.Labeled(
					{ caption = { "cybersyn2-gui.network" }, top_margin = 6 },
					{
						gui.NetworkSignalPicker(
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
					ultros.RtLabel(
						"[font=default-bold]Warning:[/font] No network signal selected."
					)
				),
				gui.InnerHeading({
					caption = "Flags",
				}),
				gui.Checkbox(
					"Use stack thresholds",
					props.combinator,
					combinator_settings.use_stack_thresholds
				),
			}),
			ultros.WellFold({ caption = "Advanced" }, {
				ultros.Labeled(
					{ caption = "Signal: Allow departure", top_margin = 6 },
					{
						gui.AnySignalPicker(
							props.combinator,
							combinator_settings.allow_departure_signal
						),
					}
				),
				ultros.Labeled(
					{ caption = "Signal: Force departure", top_margin = 6 },
					{
						gui.AnySignalPicker(
							props.combinator,
							combinator_settings.force_departure_signal
						),
					}
				),
				ultros.Labeled({ caption = "Inactivity mode", top_margin = 6 }, {
					gui.Switch(
						true,
						"After delivery",
						"Force out",
						props.combinator,
						combinator_settings.inactivity_mode
					),
				}),
				ultros.Labeled(
					{ caption = "Inactivity timeout (sec)", top_margin = 6 },
					{
						gui.Input({
							combinator = props.combinator,
							setting = combinator_settings.inactivity_timeout,
							width = 75,
							numeric = true,
							allow_decimal = false,
							allow_negative = false,
						}),
					}
				),
				gui.InnerHeading({
					caption = "Flags",
				}),
				gui.Checkbox(
					"Enable cargo condition",
					props.combinator,
					combinator_settings.disable_cargo_condition,
					true
				),
			}),
		})
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
			}, {
				ultros.BoldLabel("Signal"),
				ultros.BoldLabel("Effect"),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel(
					"Set station inventory. Positive values indicate available cargo, while negative values indicate requested cargo."
				),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-priority]"),
				ultros.RtMultilineLabel(
					"Set the priority for all items at this station."
				),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-items]"),
				ultros.RtMultilineLabel(
					"Set the inbound and outbound delivery threshold for all items at this station."
				),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-fluids]"),
				ultros.RtMultilineLabel(
					"Set the inbound and outbound delivery threshold for all fluids at this station."
				),
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
	is_input = true,
})
