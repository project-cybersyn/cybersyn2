--------------------------------------------------------------------------------
-- Allowlist combinator
--------------------------------------------------------------------------------

local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local tlib = require("lib.core.table")
local stlib = require("lib.core.strace")
local cs2 = _G.cs2
local gui = _G.cs2.gui

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

---@class Cybersyn.Combinator
---@field public get_allow_mode fun(): "auto" | "layout" | "group" | "all" LEGACY: old allowlist
---@field public get_allowed_layouts fun(): string[][] Manual allowlist entries

cs2.register_raw_setting("allow_mode", "allow_mode", "auto")
cs2.register_raw_setting("allowed_layouts", "layouts", {})

--------------------------------------------------------------------------------
-- Layout string utils
--------------------------------------------------------------------------------

---Parse a layout string into an array of item prototype names.
---Layout strings consist of [item] entries in Factorio rich text format.
---Whitespace and quality information are ignored.
---@param layout_string string
---@return string[]
local function parse_layout_string(layout_string)
	local items = {}
	for item in layout_string:gmatch("%[item=([^%]]+)%]") do
		-- Remove quality suffix if present (e.g., "iron-plate,normal" -> "iron-plate")
		local prototype_name = item:match("^([^,]+)")
		table.insert(items, prototype_name)
	end
	return items
end

local valid_types =
	{ locomotive = true, ["cargo-wagon"] = true, ["fluid-wagon"] = true }

---Filter item prototypes to only include train car types.
---@param items string[]
---@return string[]
local function filter_carriage_prototypes(items)
	local filtered = {}
	for _, item in ipairs(items) do
		local prototype = prototypes.entity[item]
		if prototype and valid_types[prototype.type] then
			table.insert(filtered, item)
		end
	end
	return filtered
end

---Encode an array of item prototype names into a layout string.
---Produces Factorio rich text format [item] entries.
---@param items string[]
---@return string
local function encode_layout_string(items)
	local parts = {}
	for _, item in ipairs(items) do
		table.insert(parts, "[item=" .. item .. "]")
	end
	return table.concat(parts)
end

---@param layout_string string|nil
---@return string|nil
local function normalize_layout_string(layout_string)
	if not layout_string then return nil end
	local items = parse_layout_string(layout_string)
	local carriages = filter_carriage_prototypes(items)
	if #carriages == 0 then return nil end
	return encode_layout_string(carriages)
end

local function get_existing_layout_strings()
	local layout_strings = {}
	for _, layout in pairs(storage.train_layouts) do
		table.insert(layout_strings, encode_layout_string(layout.carriage_names))
	end
	return layout_strings
end

---@param strings string[]
local function to_option_list(strings)
	local options = {}
	for i = 1, #strings do
		table.insert(options, { key = i, caption = strings[i] })
	end
	return options
end

local function add_layout_if_not_exists(
	combinator,
	allowed_layouts,
	allowed_layout_strings,
	layout_string
)
	if
		tlib.find(allowed_layout_strings, function(s) return s == layout_string end)
	then
		return
	end
	local next_layouts = tlib.assign({}, allowed_layouts)
	local next_layout = parse_layout_string(layout_string)
	table.insert(next_layouts, next_layout)
	combinator:set_allowed_layouts(next_layouts)
end

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define("CombinatorGui.Mode.Allow", function(props)
	local combinator = props.combinator --[[@as Cybersyn.Combinator]]
	local allowed_layouts = combinator:get_allowed_layouts()
	local allowed_layout_strings = tlib.map(
		allowed_layouts,
		function(layout) return encode_layout_string(layout) end
	)
	local existing_layout_options = to_option_list(get_existing_layout_strings())
	local allowed_layout_options = to_option_list(allowed_layout_strings)
	local has_allowed_layouts = #allowed_layout_options > 0

	stlib.trace(
		"Rendering allow list settings GUI",
		"allowed_layouts",
		allowed_layouts
	)

	local function add_existing_layout(_, index)
		local layout_string = existing_layout_options[index].caption
		add_layout_if_not_exists(
			combinator,
			allowed_layouts,
			allowed_layout_strings,
			layout_string
		)
	end

	---@type LuaGuiElement?
	local listbox_ref
	local function set_listbox_ref(elt) listbox_ref = elt end
	---@type LuaGuiElement?
	local textbox_ref
	local function set_textbox_ref(elt) textbox_ref = elt end

	local function remove_selected_layout()
		if not listbox_ref then return end
		local selected_index = listbox_ref.selected_index
		if selected_index <= 0 then return end
		if not allowed_layout_strings[selected_index] then return end
		local next_layouts = tlib.assign({}, allowed_layouts)
		table.remove(next_layouts, selected_index)
		combinator:set_allowed_layouts(next_layouts)
	end

	---@param elt LuaGuiElement
	local function add_custom_layout(_, layout_string, elt)
		layout_string = normalize_layout_string(layout_string)
		if not layout_string then
			game.get_player(elt.player_index).print(
				"[color=red]Invalid layout string.[/color]",
				{ sound = defines.print_sound.always, skip = defines.print_skip.never }
			)
			return
		end
		add_layout_if_not_exists(
			combinator,
			allowed_layouts,
			allowed_layout_strings,
			layout_string
		)
		if textbox_ref then textbox_ref.text = "" end
	end

	return VF({
		ultros.WellSection({ caption = "Manual Allow List" }, {
			-- Editbox
			ultros.BoldLabel("Add custom layout:"),
			ultros.Input({
				numeric = false,
				icon_selector = true,
				width = 370,
				on_confirm = add_custom_layout,
				ref = set_textbox_ref,
			}),
			-- Dropdown
			ultros.BoldLabel("Add existing layout:"),
			ultros.Dropdown({
				horizontally_stretchable = true,
				options = existing_layout_options,
				on_change = add_existing_layout,
			}),
			-- Listbox
			ultros.BoldLabel("Allowed layouts:"),
			Pr({
				type = "frame",
				style = "relm_deep_frame_in_shallow_frame_stretchable",
				visible = not has_allowed_layouts,
				height = 200,
				padding = 8,
				horizontal_align = "center",
				vertical_align = "center",
			}, {
				ultros.RtMultilineLabel(
					"No allowed layouts. Use the input box or dropdown above\nto add layouts to the allow list."
				),
			}),
			ultros.Listbox({
				height = 200,
				visible = has_allowed_layouts,
				options = allowed_layout_options,
				ref = set_listbox_ref,
			}),
			-- Buttons
			ultros.Button({
				caption = "Remove selected",
				visible = has_allowed_layouts,
				on_click = remove_selected_layout,
			}),
		}),
	})
end)

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
