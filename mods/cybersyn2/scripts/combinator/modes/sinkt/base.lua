--------------------------------------------------------------------------------
-- SinkT combinator
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.SinkT",
	render = function(props)
		return nil
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.SinkT.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel(
				"When net inventory is below [font=default-bold]sink threshold[/font], other stations [font=default-bold]pushing[/font] the corresponding item will send it here."
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
					"Set sink thresholds for individual items at this station. Each item's threshold will be set to its signal value."
				),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

combinator_api.register_combinator_mode({
	name = "sinkt",
	localized_string = "cybersyn2-combinator-modes.sinkt",
	settings_element = "CombinatorGui.Mode.SinkT",
	help_element = "CombinatorGui.Mode.SinkT.Help",
})
