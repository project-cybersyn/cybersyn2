--------------------------------------------------------------------------------
-- Channels combinator
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
	name = "CombinatorGui.Mode.Channels",
	render = function(props)
		-- TODO: default channelmask as a setting?
		return nil
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Channels.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel(
				"Items can be assigned to any of 32 [font=default-bold]channels[/font] using bitmasks. Items will only be delivered between stations that have that item on the [font=default-bold]same channel[/font] as determined by the bitwise AND of the bitmasks."
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
					"Set item channels for individual items at this station. Each item's channel mask will be set to its signal value."
				),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-items]"),
				ultros.RtMultilineLabel(
					"Set the default channel mask for this station. (Applies to fluids as well.)"
				),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration.
--------------------------------------------------------------------------------

combinator_api.register_combinator_mode({
	name = "channels",
	localized_string = "cybersyn2-combinator-modes.channels",
	settings_element = "CombinatorGui.Mode.Channels",
	help_element = "CombinatorGui.Mode.Channels.Help",
})
