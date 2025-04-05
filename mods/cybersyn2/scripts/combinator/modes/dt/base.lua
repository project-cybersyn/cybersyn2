--------------------------------------------------------------------------------
-- DT combinator
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("dt_inbound", "dt_flags", 0)
)
cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("dt_outbound", "dt_flags", 1)
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.DT",
	render = function(props)
		return VF({
			ultros.WellSection({ caption = "Settings" }, {

				gui.InnerHeading({
					caption = "Flags",
				}),
				gui.Checkbox(
					"Set inbound delivery thresholds",
					props.combinator,
					combinator_settings.dt_inbound
				),
				gui.Checkbox(
					"Set outbound delivery thresholds",
					props.combinator,
					combinator_settings.dt_outbound
				),
			}),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.DT.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel(
				"Stations will not take orders below their [font=default-bold]inbound delivery threshold[/font] or send orders below their [font=default-bold]outbound delivery threshold[/font]. Thresholds apply to each item individually."
			),
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
					"Set checked thresholds for individual items at this station. Each item's threshold will be set to its signal value."
				),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-items]"),
				ultros.RtMultilineLabel(
					"Set checked thresholds for all items at this station."
				),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-fluids]"),
				ultros.RtMultilineLabel(
					"Set checked thresholds for all fluids at this station."
				),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "dt",
	localized_string = "cybersyn2-combinator-modes.dt",
	settings_element = "CombinatorGui.Mode.DT",
	help_element = "CombinatorGui.Mode.DT.Help",
})
