--------------------------------------------------------------------------------
-- DT combinator
--------------------------------------------------------------------------------

local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

---@class Cybersyn.Combinator
---@field public get_dt_inbound fun(): boolean
---@field public get_dt_outbound fun(): boolean

cs2.register_flag_setting("dt_inbound", "dt_flags", 0)
cs2.register_flag_setting("dt_outbound", "dt_flags", 1)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.DT",
	render = function(props)
		return VF({
			ultros.WellSection(
				{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
				{

					gui.InnerHeading({
						caption = { "cybersyn2-combinator-modes-labels.flags" },
					}),
					gui.Checkbox({
						"cybersyn2-combinator-mode-delivery-size.set-inbound-delivery-size",
					}, {
						"cybersyn2-combinator-mode-delivery-size.set-inbound-delivery-size-tooltip",
					}, props.combinator, "dt_inbound"),
					gui.Checkbox({
						"cybersyn2-combinator-mode-delivery-size.set-outbound-delivery-size",
					}, {
						"cybersyn2-combinator-mode-delivery-size.set-outbound-delivery-size-tooltip",
					}, props.combinator, "dt_outbound"),
				}
			),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.DT.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-delivery-size.desc",
			}),
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
					"cybersyn2-combinator-mode-delivery-size.cargo-inputs",
				}),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-items]"),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-delivery-size.all-items",
				}),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-all-fluids]"),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-delivery-size.all-fluids",
				}),
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
	is_input = true,
	is_output = false,
})
