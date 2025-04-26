--------------------------------------------------------------------------------
-- Prio combinator
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
	name = "CombinatorGui.Mode.Prio",
	render = function(props) return nil end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Prio.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-prio.desc" }),
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
				ultros.BoldLabel({ "cybersyn2-gui.signal" }),
				ultros.BoldLabel({ "cybersyn2-gui.effect" }),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-prio.set-per-item",
				}),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-priority]"),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-prio.set-all",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration.
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "prio",
	localized_string = "cybersyn2-combinator-modes.prio",
	settings_element = "CombinatorGui.Mode.Prio",
	help_element = "CombinatorGui.Mode.Prio.Help",
})
