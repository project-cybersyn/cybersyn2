--------------------------------------------------------------------------------
-- Allowlist combinator
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
-- Settings
--------------------------------------------------------------------------------

cs2.register_combinator_setting(
	cs2.lib.make_raw_setting("allow_mode", "allow_mode", "auto")
)
cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("allow_strict", "allow_flags", 0)
)
cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("allow_bidi", "allow_flags", 1)
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local mode_dropdown_items = {
	{ key = "auto", caption = { "cybersyn2-gui.allow-mode-auto" } },
	{ key = "layout", caption = { "cybersyn2-gui.allow-mode-layout" } },
	{ key = "group", caption = { "cybersyn2-gui.allow-mode-group" } },
	{ key = "all", caption = { "cybersyn2-gui.allow-mode-all" } },
}

local GroupSettings = relm.define_element({
	name = "CombinatorGui.Mode.Allow.GroupSettings",
	render = function(props) return {} end,
})

local LayoutSettings = relm.define_element({
	name = "CombinatorGui.Mode.Allow.LayoutSettings",
	render = function(props) return {} end,
})

local AutoSettings = relm.define_element({
	name = "CombinatorGui.Mode.Allow.AutoSettings",
	render = function(props)
		return {
			gui.InnerHeading({
				caption = "Flags",
			}),
			gui.Checkbox(
				"Strict allow list",
				props.combinator,
				combinator_settings.allow_strict
			),
			gui.Checkbox(
				"Bidirectional trains only",
				props.combinator,
				combinator_settings.allow_bidi
			),
		}
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Allow",
	render = function(props)
		local mode = props.combinator:read_setting(combinator_settings.allow_mode)
		return VF({
			ultros.WellSection({ caption = "Settings" }, {
				ultros.Labeled({ caption = "Allowlist mode", top_margin = 6 }, {
					gui.Dropdown(
						nil,
						props.combinator,
						combinator_settings.allow_mode,
						mode_dropdown_items
					),
				}),
				ultros.If(
					mode == "auto",
					AutoSettings({ combinator = props.combinator })
				),
				ultros.If(
					mode == "layout",
					LayoutSettings({ combinator = props.combinator })
				),
				ultros.If(
					mode == "group",
					GroupSettings({ combinator = props.combinator })
				),
			}),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Allow.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel(
				"The [font=default-bold]allow list[/font] determines which trains can be sent to this station. An automatic algorithm can be used to determine this for you based on nearby equipment, or you may choose specific train layouts or groups."
			),
		})
	end,
})

--------------------------------------------------------------------------------
-- Station combinator mode registration.
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "allow",
	localized_string = "cybersyn2-gui.allow-list",
	settings_element = "CombinatorGui.Mode.Allow",
	help_element = "CombinatorGui.Mode.Allow.Help",
})
