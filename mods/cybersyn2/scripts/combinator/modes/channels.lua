--------------------------------------------------------------------------------
-- Channels combinator
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
	name = "CombinatorGui.Mode.Channels",
	render = function(props) return nil end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Channels.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-channels.desc" }),
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = { "cybersyn2-combinator-modes-labels.signal-inputs" },
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
			}, {
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.signal" }),
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.effect" }),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-channels.item-channels",
				}),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-items]"),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-channels.all-item-channels",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration.
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "channels",
	localized_string = "cybersyn2-combinator-modes.channels",
	settings_element = "CombinatorGui.Mode.Channels",
	help_element = "CombinatorGui.Mode.Channels.Help",
})
