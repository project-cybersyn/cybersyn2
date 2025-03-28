--------------------------------------------------------------------------------
-- Allowlist combinator
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local combinator_settings = _G.cs2.combinator_settings

local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

combinator_api.register_setting(
	combinator_api.make_raw_setting("allow_mode", "allow_mode", "auto")
)
combinator_api.register_setting(
	combinator_api.make_flag_setting("allow_strict", "allow_flags", 0)
)
combinator_api.register_setting(
	combinator_api.make_flag_setting("allow_bidi", "allow_flags", 1)
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local mode_dropdown_items = {
	{ "cybersyn2-gui.allow-mode-auto" },
	{ "cybersyn2-gui.allow-mode-layout" },
	{ "cybersyn2-gui.allow-mode-group" },
	{ "cybersyn2-gui.allow-mode-all" },
}

local mode_names = { "auto", "layout", "group", "all" }

---@param event flib.GuiEventData
---@param combinator Cybersyn.Combinator.Ephemeral
local function handle_mode_dropdown(event, combinator)
	local element = event.element
	if not element then
		return
	end
	local new_mode = mode_names[element.selected_index] or "auto"
	combinator_api.write_setting(
		combinator,
		combinator_settings.allow_mode,
		new_mode
	)
end

---@param parent LuaGuiElement
local function create_gui(parent)
	flib_gui.add(parent, {
		{
			type = "label",
			style = "heading_2_label",
			caption = { "cybersyn2-gui.settings" },
			style_mods = { top_padding = 8 },
		},
		{
			type = "flow",
			name = "mode_flow",
			direction = "horizontal",
			style_mods = {
				vertical_align = "center",
				horizontally_stretchable = true,
			},
			children = {
				{
					type = "label",
					caption = { "cybersyn2-gui.allow-mode" },
				},
				{
					type = "flow",
					style_mods = { horizontally_stretchable = true },
				},
				{
					type = "drop-down",
					name = "mode_dropdown",
					style_mods = { top_padding = 3, right_margin = 8 },
					handler = handle_mode_dropdown,
					selected_index = 1,
					items = mode_dropdown_items,
				},
			},
		},
		{
			type = "checkbox",
			name = "allow_strict",
			state = false,
			handler = combinator_api.generic_checkbox_handler,
			tags = { setting = "allow_strict" },
			tooltip = { "cybersyn2-gui.allow-strict-tooltip" },
			caption = { "cybersyn2-gui.allow-strict-description" },
		},
		{
			type = "checkbox",
			name = "allow_bidi",
			state = false,
			handler = combinator_api.generic_checkbox_handler,
			tags = { setting = "allow_bidi" },
			tooltip = { "cybersyn2-gui.allow-bidi-tooltip" },
			caption = { "cybersyn2-gui.allow-bidi-description" },
		},
	})
end

---@param parent LuaGuiElement
---@param settings Cybersyn.Combinator.Ephemeral
---@param changed_setting_name string?
local function update_gui(parent, settings, changed_setting_name)
	local allow_mode =
		combinator_api.read_setting(settings, combinator_settings.allow_mode)

	if allow_mode == "auto" then
		-- Unhide auto-mode checkboxes
		parent["allow_strict"].visible = true
		parent["allow_bidi"].visible = true
	else
		-- Hide auto-mode checkboxes
		parent["allow_strict"].visible = false
		parent["allow_bidi"].visible = false
	end

	parent["allow_strict"].state =
		combinator_api.read_setting(settings, combinator_settings.allow_strict)
	parent["allow_bidi"].state =
		combinator_api.read_setting(settings, combinator_settings.allow_bidi)

	local _, mode_index = tlib.find(mode_names, function(x)
		return x == allow_mode
	end)
	parent["mode_flow"]["mode_dropdown"].selected_index = mode_index or 1
end

relm.define_element({
	name = "CombinatorGui.Mode.Allow",
	render = function(props)
		return VF({ Pr({ type = "label", caption = "Allowlist combinator" }) })
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Allow.Help",
	render = function(props)
		return VF({ Pr({ type = "label", caption = "Allowlist combinator help" }) })
	end,
})

--------------------------------------------------------------------------------
-- Station combinator mode registration.
--------------------------------------------------------------------------------

combinator_api.register_combinator_mode({
	name = "allow",
	localized_string = "cybersyn2-gui.allow-list",
	settings_element = "CombinatorGui.Mode.Allow",
	help_element = "CombinatorGui.Mode.Allow.Help",
})
