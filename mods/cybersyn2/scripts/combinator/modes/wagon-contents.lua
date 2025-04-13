--------------------------------------------------------------------------------
-- Wagon contents output combinator
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local signal_lib = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local Delivery = _G.cs2.Delivery
local signal_to_key = signal_lib.signal_to_key
local key_to_signal = signal_lib.key_to_signal
local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.WagonContents",
	render = function(props) return nil end,
})

relm.define_element({
	name = "CombinatorGui.Mode.WagonContents.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-wagon-contents.desc",
			}),
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = { "cybersyn2-combinator-modes-labels.signal-outputs" },
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
			}, {
				ultros.BoldLabel("Signal"),
				ultros.BoldLabel("Value"),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-wagon-contents.output-signals",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "wagon-contents",
	localized_string = "cybersyn2-combinator-modes.wagon-contents",
	settings_element = "CombinatorGui.Mode.WagonContents",
	help_element = "CombinatorGui.Mode.WagonContents.Help",
	is_output = true,
})

--------------------------------------------------------------------------------
-- Impl
--------------------------------------------------------------------------------

cs2.on_train_arrived(function(train, cstrain, stop)
	if not cstrain or not stop then return end
end)

cs2.on_train_departed(function(train, cstrain, stop)
	if not cstrain or not stop then return end
end)
