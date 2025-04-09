--------------------------------------------------------------------------------
-- PushT combinator
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
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.PushT",
	render = function(props) return nil end,
})

relm.define_element({
	name = "CombinatorGui.Mode.PushT.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel(
				"When net inventory is above the (nonzero positive) [font=default-bold]push threshold[/font], the remainder above the threshold will be offered to [font=default-bold]sinks[/font] and [font=default-bold]dumps[/font]."
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
					"Set push thresholds for individual items at this station. Each item's threshold will be set to its signal value."
				),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "pusht",
	localized_string = "cybersyn2-combinator-modes.pusht",
	settings_element = "CombinatorGui.Mode.PushT",
	help_element = "CombinatorGui.Mode.PushT.Help",
})
