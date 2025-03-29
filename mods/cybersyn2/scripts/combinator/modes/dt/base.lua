--------------------------------------------------------------------------------
-- DT combinator
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
-- Settings
--------------------------------------------------------------------------------

combinator_api.register_setting(
	combinator_api.make_flag_setting("dt_inbound", "dt_flags", 0)
)
combinator_api.register_setting(
	combinator_api.make_flag_setting("dt_outbound", "dt_flags", 1)
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.DT",
	render = function(props)
		local mode = combinator_api.read_setting(
			props.combinator,
			combinator_settings.allow_mode
		)
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
		return VF({ Pr({ type = "label", caption = "Incomplete help" }) })
	end,
})

--------------------------------------------------------------------------------
-- Station combinator mode registration.
--------------------------------------------------------------------------------

combinator_api.register_combinator_mode({
	name = "dt",
	localized_string = "cybersyn2-combinator-modes.dt",
	settings_element = "CombinatorGui.Mode.DT",
	help_element = "CombinatorGui.Mode.DT.Help",
})
