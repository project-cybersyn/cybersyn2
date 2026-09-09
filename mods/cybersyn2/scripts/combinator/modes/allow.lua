--------------------------------------------------------------------------------
-- Allowlist combinator
--------------------------------------------------------------------------------

local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local strace = require("lib.core.strace")
local scheduler = require("lib.core.scheduler")

local cs2 = _G.cs2

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

---@class (partial) Cybersyn.Combinator
---@field public get_allow_mode fun(): "auto" | "layout" | "group" | "all" LEGACY: old allowlist
---@field public get_allowed_layouts fun(): string[][] Manual allowlist entries
---@field public set_allowed_layouts fun(self: Cybersyn.Combinator, layouts: string[][]): void
---@field public get_group_id fun(): int ID of assigned group (0 = none)
---@field public set_group_id fun(self: Cybersyn.Combinator, group_id: int): void

cs2.register_raw_setting("allow_mode", "allow_mode", "auto")
cs2.register_raw_setting("allowed_layouts", "layouts", {})
cs2.register_raw_setting("group_id", "group_id", 0)

--------------------------------------------------------------------------------
-- Group Storage Helpers
--------------------------------------------------------------------------------

local function get_or_create_allow_groups()
	if not storage.allow_groups then storage.allow_groups = {} end
	if not storage.next_allow_group_id then storage.next_allow_group_id = 1 end
	return storage.allow_groups
end

local function get_allow_group(group_id)
	if not group_id or group_id == 0 then return nil end
	local groups = get_or_create_allow_groups()
	return groups[group_id]
end

local function find_group_by_name(name)
	local groups = get_or_create_allow_groups()
	for _, grp in pairs(groups) do
		if grp.name == name then
			return grp
		end
	end
	return nil
end

-- Route layout updates to either the group or the local combinator
local function update_active_layouts(combinator, group, next_layouts)
	if group then
		group.layouts = next_layouts
		events.raise("cs2.allow_group_updated", group.id)
	else
		combinator:set_allowed_layouts(next_layouts)
	end
end

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
	group,
	allowed_layouts,
	allowed_layout_strings,
	layout_string,
	elt
)
	if
		tlib.find(allowed_layout_strings, function(s) return s == layout_string end)
	then
		return
	end
	local next_layouts = tlib.assign({}, allowed_layouts)
	local next_layout = parse_layout_string(layout_string)
	table.insert(next_layouts, next_layout)
	update_active_layouts(combinator, group, next_layouts)

	if group and elt and elt.player_index then
		cs2.update_player_state(elt.player_index, "open_combinator", combinator)
	end
end

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define("CombinatorGui.Mode.Allow", function(props)
	local combinator = props.combinator --[[@as Cybersyn.Combinator]]

	local group_id = combinator:get_group_id() or 0
	local active_group = get_allow_group(group_id)

	local allowed_layouts = active_group and active_group.layouts or combinator:get_allowed_layouts()
	local allowed_layout_strings = tlib.map(
		allowed_layouts,
		function(layout) return encode_layout_string(layout) end
	)
	local existing_layout_options = to_option_list(get_existing_layout_strings())
	local allowed_layout_options = to_option_list(allowed_layout_strings)
	local has_allowed_layouts = #allowed_layout_options > 0

	local groups = get_or_create_allow_groups()
	local group_options = { { key = 0, caption = { "cybersyn2-combinator-mode-allow.no-group-option" } }, }
	for _, grp in pairs(groups) do
		table.insert(group_options, { key = grp.id, caption = { "", grp.name } })
	end

	local function on_select_group(_, key)
		if key then
			combinator:set_group_id(key)
		end
	end

	local function on_group_name_confirm(_, name, elt, gui_event)
		if not name or name == "" then return end

		local existing_group = find_group_by_name(name)
		if existing_group then
			combinator:set_group_id(existing_group.id)
			return
		end

		local is_ctrl = gui_event and gui_event.control

		if is_ctrl then
			if active_group then
				active_group.name = name
				if elt and elt.player_index then
					cs2.update_player_state(elt.player_index, "open_combinator", combinator)
				end
			end
		else
			local all_groups = get_or_create_allow_groups()
			local new_id = storage.next_allow_group_id or 1
			storage.next_allow_group_id = new_id + 1
			all_groups[new_id] = {
				id = new_id,
				name = name,
				layouts = tlib.assign({}, combinator:get_allowed_layouts()),
			}
			combinator:set_group_id(new_id)
		end
	end

	local function add_existing_layout(_, index, elt)
		local layout_string = existing_layout_options[index].caption
		add_layout_if_not_exists(
			combinator,
			active_group,
			allowed_layouts,
			allowed_layout_strings,
			layout_string,
			elt
		)
	end

	---@type LuaGuiElement?
	local listbox_ref
	local function set_listbox_ref(elt) listbox_ref = elt end
	---@type LuaGuiElement?
	local textbox_ref
	local function set_textbox_ref(elt) textbox_ref = elt end

	local function remove_selected_layout(_, elt)
		if not listbox_ref then return end
		local selected_index = listbox_ref.selected_index
		if selected_index <= 0 then return end
		if not allowed_layout_strings[selected_index] then return end
		local next_layouts = tlib.assign({}, allowed_layouts)
		table.remove(next_layouts, selected_index)
		update_active_layouts(combinator, active_group, next_layouts)

		if active_group and elt and elt.player_index then
			cs2.update_player_state(elt.player_index, "open_combinator", combinator)
		end
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
			active_group,
			allowed_layouts,
			allowed_layout_strings,
			layout_string,
			elt
		)
		if textbox_ref then textbox_ref.text = "" end
	end

	return VF({
		ultros.WellSection({ caption = { "cybersyn2-combinator-mode-allow.group-config-header" } }, {
			ultros.BoldLabel({ "cybersyn2-combinator-mode-allow.select-group" }),
			ultros.Dropdown({
				horizontally_stretchable = true,
				options = group_options,
				value = group_id,
				on_change = on_select_group,
			}),
			ultros.BoldLabel({ "cybersyn2-combinator-mode-allow.group-name-label" }),
			ultros.Input({
				text = active_group and active_group.name or "",
				width = 370,
				on_confirm = on_group_name_confirm,
				tooltip = { "cybersyn2-combinator-mode-allow.group-name-tooltip" },
			}),
		}),
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

--------------------------------------------------------------------------------
-- Blueprint & copy events
--------------------------------------------------------------------------------

local function get_combinator_from_entity(entity)
	if not (entity and entity.valid) then return nil end
	local ok, _, id = pcall(remote.call, "things", "get_thing_id", entity)
	if ok and id then
		return cs2.get_combinator(id)
	end
	return nil
end

events.bind(defines.events.on_player_setup_blueprint, function(event)
	local item = event.record or event.stack
	if not (item and item.valid_for_read) then
		return
	end

	local mapping = event.mapping.get()
	for i, entity in pairs(mapping) do
		if entity.valid and entity.name == "cybersyn2-combinator" then
			local comb = get_combinator_from_entity(entity)
			if comb and comb.mode == "allow" then
				local group_id = comb:get_group_id()
				local group = get_allow_group(group_id)
				if group then
					item.set_blueprint_entity_tag(i, "group_id", 0)
					item.set_blueprint_entity_tag(i, "group_name", group.name)
					item.set_blueprint_entity_tag(i, "group_layouts", group.layouts)
				end
			end
		end
	end
end)

events.bind("cybersyn2-combinator-on_initialized", function(event)
	local comb = cs2.get_combinator(event.id)
	if not comb then return end

	local tags = event.tags
	if not (tags and tags.group_name) then game.print("no group name") return end

	local group_name = tags.group_name
	local group_layouts = tags.group_layouts or {}

	local group = find_group_by_name(group_name)
	if not group then
		local new_id = storage.next_allow_group_id or 1
		storage.next_allow_group_id = new_id + 1
		group = {
			id = new_id,
			name = group_name,
			layouts = group_layouts,
		}
		storage.allow_groups[new_id] = group
	end

	comb:set_group_id(group.id)
end)