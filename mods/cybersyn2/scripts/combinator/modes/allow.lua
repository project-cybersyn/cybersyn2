--------------------------------------------------------------------------------
-- Allowlist combinator
--------------------------------------------------------------------------------

local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local cs2 = _G.cs2
local gui = _G.cs2.gui

local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

-- LEGACY: old allow list

---@class Cybersyn.Combinator
---@field public get_allow_mode fun(): "auto" | "layout" | "group" | "all"

cs2.register_raw_setting("allow_mode", "allow_mode", "auto")

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Allow",
	render = function(props) return VF({}) end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Allow.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel(
				"The [font=default-bold]allow list[/font] determines which trains can be sent to this station. This combinator lets you create and manage custom allow lists."
			),
		})
	end,
})

--------------------------------------------------------------------------------
-- Station combinator mode registration.
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "allow",
	localized_string = "cybersyn2-combinator-modes.allow-list",
	settings_element = "CombinatorGui.Mode.Allow",
	help_element = "CombinatorGui.Mode.Allow.Help",
})
