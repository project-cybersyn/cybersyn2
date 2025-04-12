--------------------------------------------------------------------------------
-- Dump combinator
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
	name = "CombinatorGui.Mode.Dump",
	render = function(props) return nil end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Dump.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel(
				"Makes this station a [font=default-bold]dump[/font] that will accept all products being [font=default-bold]pushed[/font] on specific channels. A channels combinator is also mandatory at a dump station."
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
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-items]"),
				ultros.RtMultilineLabel(
					"Number of [font=default-bold]free item slots[/font] available at this dump. Net item deliveries will not exceed total available slots."
				),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-fluids]"),
				ultros.RtMultilineLabel(
					"Amount of [font=default-bold]available fluid capacity[/font] at this dump. Net fluid deliveries will not exceed this amount."
				),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "dump",
	localized_string = "cybersyn2-combinator-modes.dump",
	settings_element = "CombinatorGui.Mode.Dump",
	help_element = "CombinatorGui.Mode.Dump.Help",
})
