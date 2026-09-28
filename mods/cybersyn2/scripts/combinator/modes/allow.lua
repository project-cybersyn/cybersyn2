--------------------------------------------------------------------------------
-- Allowlist combinator
--------------------------------------------------------------------------------

local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local events = require("lib.core.event")
local tlib = require("lib.core.table")
local strace = require("lib.core.strace")
local cs2 = _G.cs2

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local tinsert = table.insert
local ipairs = ipairs

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

---@class (partial) Cybersyn.Combinator
---@field public get_allow_mode fun(): "auto" | "layout" | "group" | "all" LEGACY: old allowlist
---@field public get_allowed_layouts fun(): string[][] Manual allowlist entries
---@field public set_allowed_layouts fun(self: Cybersyn.Combinator, layouts: string[][]): void
---@field public get_allow_group fun(): string Name of the group whose allow list is shared, `""` for a local allow list
---@field public set_allow_group fun(self: Cybersyn.Combinator, name: string)

cs2.register_raw_setting("allow_mode", "allow_mode", "auto")
cs2.register_raw_setting("allowed_layouts", "layouts", {})

-- The name of the group whose allow list this combinator shares.
cs2.register_raw_setting("allow_group", "allow_group", "")

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
		tinsert(items, prototype_name)
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
			tinsert(filtered, item)
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
		tinsert(parts, "[item=" .. item .. "]")
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
		tinsert(layout_strings, encode_layout_string(layout.carriage_names))
	end
	return layout_strings
end

---@param strings string[]
local function to_option_list(strings)
	local options = {}
	for i = 1, #strings do
		tinsert(options, { key = i, caption = strings[i] })
	end
	return options
end

--------------------------------------------------------------------------------
-- Allow groups
--
-- Members of a group share its allow list. Name and list are Things tags, so a
-- group travels through blueprints by itself.
--------------------------------------------------------------------------------

---@return table<string, Cybersyn.AllowGroup> Absent in saves predating groups.
local function get_allow_groups()
	if not storage.allow_groups then storage.allow_groups = {} end
	return storage.allow_groups
end

---@param name string
---@return Cybersyn.AllowGroup?
local function find_group_by_name(name) return get_allow_groups()[name] end

---@param name string
---@param layouts string[][]
---@return Cybersyn.AllowGroup
local function create_group(name, layouts)
	local group = { name = name, layouts = tlib.deep_copy(layouts) }
	get_allow_groups()[name] = group
	return group
end

---@param combinator Cybersyn.Combinator
---@param name string
---@return boolean
local function is_group_member(combinator, name)
	return name ~= ""
		and combinator.mode == "allow"
		and combinator:get_allow_group() == name
end

---The allow list that a combinator applies: The one of its group if the save
---knows that group, else the one that the combinator carries itself.
---@param combinator Cybersyn.Combinator
---@return string[][]
function cs2.get_manual_allow_list(combinator)
	local group = find_group_by_name(combinator:get_allow_group())
	return group and group.layouts or combinator:get_allowed_layouts()
end

---The group of a combinator, creating it from its own allow list if unknown.
---@param combinator Cybersyn.Combinator
---@return Cybersyn.AllowGroup?
local function resolve_group(combinator)
	if combinator.mode ~= "allow" then return nil end
	local name = combinator:get_allow_group()
	if name == "" then return nil end
	return find_group_by_name(name)
		or create_group(name, combinator:get_allowed_layouts())
end

---@return string[]
local function get_group_names()
	local names = {}
	for _, group in pairs(get_allow_groups()) do
		names[#names + 1] = group.name
	end
	table.sort(names)
	return names
end

---@param combinator Cybersyn.Combinator
---@param group Cybersyn.AllowGroup
local function sync_group_member(combinator, group)
	combinator:set_allowed_layouts(tlib.deep_copy(group.layouts))
end

---Set the layouts of a group and of all of its members.
---@param group Cybersyn.AllowGroup
---@param next_layouts string[][]
---@param source Cybersyn.Combinator Already carries `next_layouts`.
local function set_group_layouts(group, next_layouts, source)
	group.layouts = tlib.deep_copy(next_layouts)
	for _, combinator in pairs(storage.combinators) do
		if combinator ~= source and is_group_member(combinator, group.name) then
			combinator:set_allowed_layouts(tlib.deep_copy(next_layouts))
		end
	end
end

---@param combinator Cybersyn.Combinator
---@param group Cybersyn.AllowGroup?
---@param next_layouts string[][]
local function set_allow_list(combinator, group, next_layouts)
	combinator:set_allowed_layouts(next_layouts)
	if group then set_group_layouts(group, next_layouts, combinator) end
end

---@param combinator Cybersyn.Combinator
---@param group Cybersyn.AllowGroup
local function join_group(combinator, group)
	combinator:set_allow_group(group.name)
	sync_group_member(combinator, group)
end

---Dissolves a group into another one.
---@param group Cybersyn.AllowGroup
---@param target Cybersyn.AllowGroup
local function merge_group(group, target)
	if group == target then return end
	local name = group.name
	for _, combinator in pairs(storage.combinators) do
		if is_group_member(combinator, name) then
			combinator:set_allow_group(target.name)
			sync_group_member(combinator, target)
		end
	end
	get_allow_groups()[name] = nil
end

---Renames a group, dissolving it into the group of that name if one exists.
---@param group Cybersyn.AllowGroup
---@param new_name string
local function rename_group(group, new_name)
	if group.name == new_name then return end
	local target = find_group_by_name(new_name)
	if target then
		merge_group(group, target)
		return
	end
	local name = group.name
	get_allow_groups()[name] = nil
	get_allow_groups()[new_name] = group
	group.name = new_name
	for _, combinator in pairs(storage.combinators) do
		if is_group_member(combinator, name) then
			combinator:set_allow_group(new_name)
		end
	end
end

-- A combinator built from a blueprint already has all of its settings by the
-- time cs2 learns of it, so it never sees a setting change for it. Adopt its
-- group here, with an already existing group of the same name keeping its own
-- layouts over the ones the blueprint brought along.
local function adopt_group(combinator)
	local group = resolve_group(combinator)
	if group then sync_group_member(combinator, group) end
end

events.bind("cs2.combinator_created", adopt_group)

cs2.on_combinator_setting_changed(function(combinator, setting)
	-- Detect imposition of tags on to existing allow combinator and re-adopt group if needed
	if combinator.mode == "allow" and setting == nil then
		adopt_group(combinator)
	end
end)

local function add_layout_if_not_exists(
	combinator,
	group,
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
	tinsert(next_layouts, next_layout)
	set_allow_list(combinator, group, next_layouts)
end

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define("CombinatorGui.Mode.Allow", function(props)
	local combinator = props.combinator --[[@as Cybersyn.Combinator]]

	local group_name = combinator:get_allow_group()
	local group = find_group_by_name(group_name)
	local allowed_layouts = combinator:get_allowed_layouts()
	local allowed_layout_strings = tlib.map(
		allowed_layouts,
		function(layout) return encode_layout_string(layout) end
	)
	local existing_layout_options = to_option_list(get_existing_layout_strings())
	local allowed_layout_options = to_option_list(allowed_layout_strings)
	local has_allowed_layouts = #allowed_layout_options > 0

	local group_options = {
		{
			key = "",
			caption = { "cybersyn2-combinator-mode-allow.no-group-option" },
		},
	}
	for _, name in ipairs(get_group_names()) do
		tinsert(group_options, { key = name, caption = { "", name } })
	end

	local function on_select_group(_, name)
		if not name or name == group_name then return end
		if name == "" then
			combinator:set_allow_group("")
		else
			local existing = find_group_by_name(name)
			if existing then join_group(combinator, existing) end
		end
	end

	local function on_group_name_confirm(_, name, _, gui_event)
		if name == "" or name == group_name then return end
		-- Ctrl + Enter renames instead of joining.
		if group and gui_event.control then
			rename_group(group, name)
		else
			join_group(
				combinator,
				find_group_by_name(name) or create_group(name, allowed_layouts)
			)
		end
	end

	local function add_existing_layout(_, index)
		local layout_string = existing_layout_options[index].caption
		add_layout_if_not_exists(
			combinator,
			group,
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
		set_allow_list(combinator, group, next_layouts)
	end

	---@param elt LuaGuiElement
	local function add_custom_layout(_, layout_string, elt)
		layout_string = normalize_layout_string(layout_string)
		if not layout_string then
			-- This cannot be nil because the player clicking must be a real player.
			---@diagnostic disable-next-line: need-check-nil
			game.get_player(elt.player_index).print(
				{ "cybersyn2-combinator-mode-allow.invalid-layout-string" },
				{ sound = defines.print_sound.always, skip = defines.print_skip.never }
			)
			return
		end
		add_layout_if_not_exists(
			combinator,
			group,
			allowed_layouts,
			allowed_layout_strings,
			layout_string
		)
		if textbox_ref then textbox_ref.text = "" end
	end

	return VF({
		ultros.WellSection(
			{ caption = { "cybersyn2-combinator-mode-allow.manual-allow-list" } },
			{
				-- Listbox
				ultros.BoldLabel({ "cybersyn2-combinator-mode-allow.allowed-layouts" }),
				Pr({
					type = "frame",
					style = "relm_deep_frame_in_shallow_frame_stretchable",
					visible = not has_allowed_layouts,
					height = 200,
					padding = 8,
					horizontal_align = "center",
					vertical_align = "center",
				}, {
					ultros.RtMultilineLabel({
						"cybersyn2-combinator-mode-allow.no-layouts",
					}),
				}),
				ultros.Listbox({
					height = 200,
					visible = has_allowed_layouts,
					options = allowed_layout_options,
					ref = set_listbox_ref,
				}),
				-- Buttons
				ultros.Button({
					caption = { "cybersyn2-combinator-mode-allow.remove-selected" },
					visible = has_allowed_layouts,
					on_click = remove_selected_layout,
				}),
				-- Dropdown
				ultros.BoldLabel({
					"cybersyn2-combinator-mode-allow.add-existing-layout",
				}),
				ultros.Dropdown({
					horizontally_stretchable = true,
					options = existing_layout_options,
					on_change = add_existing_layout,
					tooltip = {
						"cybersyn2-combinator-mode-allow.existing-layout-tooltip",
					},
				}),
				-- Editbox
				ultros.BoldLabel({
					"cybersyn2-combinator-mode-allow.add-custom-layout",
				}),
				ultros.Input({
					numeric = false,
					icon_selector = true,
					width = 370,
					on_confirm = add_custom_layout,
					ref = set_textbox_ref,
					tooltip = { "cybersyn2-combinator-mode-allow.custom-layout-tooltip" },
				}),
			}
		),
		ultros.WellSection(
			{ caption = { "cybersyn2-combinator-mode-allow.group-config-header" } },
			{
				ultros.BoldLabel({ "cybersyn2-combinator-mode-allow.select-group" }),
				ultros.Dropdown({
					horizontally_stretchable = true,
					options = group_options,
					value = group_name,
					on_change = on_select_group,
					tooltip = { "cybersyn2-combinator-mode-allow.select-group-tooltip" },
				}),
				ultros.BoldLabel({
					"cybersyn2-combinator-mode-allow.group-name-label",
				}),
				ultros.Input({
					numeric = false,
					value = group_name,
					width = 370,
					on_confirm = on_group_name_confirm,
					tooltip = { "cybersyn2-combinator-mode-allow.group-name-tooltip" },
				}),
			}
		),
	})
end)

relm.define_element({
	name = "CombinatorGui.Mode.Allow.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-allow.desc" }),
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-allow.groups-desc" }),
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
