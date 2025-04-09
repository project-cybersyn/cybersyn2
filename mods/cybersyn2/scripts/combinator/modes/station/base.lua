--------------------------------------------------------------------------------
-- Station combinator.
--------------------------------------------------------------------------------

local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local cs2 = _G.cs2
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
cs2.register_combinator_setting(
	cs2.lib.make_raw_setting("network_signal", "network")
)
-- Whether the station should provide, request, or both.
-- 0 = p/r, 1 = p, 2 = r
cs2.register_combinator_setting(cs2.lib.make_raw_setting("pr", "pr"))
cs2.register_combinator_setting(
	cs2.lib.make_raw_setting("allow_departure_signal", "allow_departure_signal")
)
cs2.register_combinator_setting(
	cs2.lib.make_raw_setting("force_departure_signal", "force_departure_signal")
)
-- How to apply inactivity timeouts
-- 0 = disabled, 1 = after delivery, 2 = force out
cs2.register_combinator_setting(
	cs2.lib.make_raw_setting("inactivity_mode", "inactivity_mode")
)
cs2.register_combinator_setting(
	cs2.lib.make_raw_setting("inactivity_timeout", "inactivity_timeout")
)

cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("use_stack_thresholds", "station_flags", 0)
)
cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("disable_cargo_condition", "station_flags", 1)
)
-- TODO: impl
cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("produce_single_item", "station_flags", 2)
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
						"Determines whether deliveries can pick up, drop off, or both.",
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
					props.combinator:read_setting(combinator_settings.network_signal)
						== nil,
					ultros.RtLabel(
						"[font=default-bold]Warning:[/font] No network signal selected."
					)
				),
				gui.InnerHeading({
					caption = "Flags",
				}),
				gui.Checkbox(
					"Use stack thresholds",
					"If checked, all item delivery thresholds will be interpreted as stacks of items. If unchecked, all item delivery thresholds will be interpreted as individual items.",
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
						"Determines how the inactivity timer will apply. After delivery means the train will wait the appropriate number of seconds after emptying its cargo. Force out means the train will be forced out after the appropriate number of seconds, regardless of whether it has emptied its cargo. The center position disables inactivity timeouts.",
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
					"If checked, trains will receive a wait condition requiring them to pick up or drop off their cargo. If unchecked, you must manually control the train's departure using custom logic.",
					props.combinator,
					combinator_settings.disable_cargo_condition,
					true
				),
				gui.Checkbox(
					"Single item per outgoing train",
					"If checked, this station will never load multiple items onto an outgoing train, instead loading only the first matching item.",
					props.combinator,
					combinator_settings.produce_single_item
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

cs2.register_combinator_mode({
	name = "station",
	localized_string = "cybersyn2-gui.station",
	settings_element = "CombinatorGui.Mode.Station",
	help_element = "CombinatorGui.Mode.Station.Help",
	is_input = true,
})
