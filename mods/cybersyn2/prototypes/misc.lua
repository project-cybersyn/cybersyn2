data:extend({
	{
		type = "custom-input",
		name = "cybersyn2-linked-clear-cursor",
		key_sequence = "",
		linked_game_control = "clear-cursor",
	},
	{
		type = "custom-input",
		name = "cybersyn2-click",
		key_sequence = "mouse-button-1",
	},
	{
		type = "selection-tool",
		name = "cybersyn2-connection-tool",
		icon = "__cybersyn2__/graphics/icons/group-signal.png",
		icon_size = 64,
		flags = { "only-in-cursor", "spawnable", "not-stackable" },
		hidden = true,
		stack_size = 1,
		draw_label_for_cursor_render = false,
		select = {
			border_color = { r = 0.0, g = 1.0, b = 0.0 },
			cursor_box_type = "entity",
			mode = { "any-entity", "same-force" },
			entity_filter_mode = "whitelist",
			entity_filters = { "train-stop" },
		},
		alt_select = {
			border_color = { r = 0.0, g = 1.0, b = 0.0 },
			cursor_box_type = "entity",
			mode = { "any-entity", "same-force" },
			entity_filter_mode = "whitelist",
			entity_filters = { "train-stop" },
		},
	},
})
