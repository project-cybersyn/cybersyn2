local graphics = "__cybersyn2-manager__/graphics/"

data:extend({
	{
		type = "selection-tool",
		name = "cybersyn2-inspector",
		icon = graphics .. "inspector-icon.png",
		icon_size = 64,
		flags = { "only-in-cursor", "spawnable", "not-stackable" },
		-- hidden_in_factoriopedia = true,
		hidden = true,
		stack_size = 1,
		draw_label_for_cursor_render = false,
		-- selection_cursor_box_type="entity",
		select = {
			border_color = { r = 100 / 255, g = 149 / 255, b = 237 / 255, a = 1 },
			cursor_box_type = "entity",
			mode = { "any-entity", "same-force" },
			entity_filter_mode = "whitelist",
			entity_filters = { "cybersyn2-combinator", "train-stop" },
			entity_type_filters = { "locomotive" },
		},
		alt_select = {
			border_color = { r = 100 / 255, g = 149 / 255, b = 237 / 255, a = 1 },
			cursor_box_type = "entity",
			mode = { "any-entity", "same-force" },
			entity_filter_mode = "whitelist",
			entity_filters = { "cybersyn2-combinator", "train-stop" },
			entity_type_filters = { "locomotive" },
		},
	},
	{
		type = "custom-input",
		name = "cybersyn2-inspector-keybind",
		key_sequence = "",
		action = "spawn-item",
		item_to_spawn = "cybersyn2-inspector",
	},
	{
		type = "custom-input",
		name = "cybersyn2-manager-keybind",
		key_sequence = "",
		action = "lua",
	},
	{
		type = "shortcut",
		name = "cybersyn2-inspector-shortcut",
		icon = graphics .. "inspector-toolbar-white.png",
		small_icon = graphics .. "inspector-toolbar-white.png",
		action = "spawn-item",
		icon_size = 32,
		small_icon_size = 32,
		item_to_spawn = "cybersyn2-inspector",
		style = "blue",
		associated_control_input = "cybersyn2-inspector-keybind",
		-- TODO: add unlock technology
	},
	{
		type = "shortcut",
		name = "cybersyn2-manager-shortcut",
		icon = graphics .. "manager-toolbar-white.png",
		small_icon = graphics .. "manager-toolbar-white.png",
		icon_size = 32,
		small_icon_size = 32,
		toggleable = true,
		action = "lua",
		style = "blue",
		associated_control_input = "cybersyn2-manager-keybind",
	},
})
