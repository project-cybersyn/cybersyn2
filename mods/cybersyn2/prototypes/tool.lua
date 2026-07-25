data:extend({
	{
		type = "custom-input",
		name = "cybersyn2-manager-keybind",
		key_sequence = "",
		action = "lua",
	},
	{
		type = "shortcut",
		name = "cybersyn2-manager-shortcut",
		icon = "__cybersyn2__/graphics/icons/manager-toolbar-white.png",
		small_icon = "__cybersyn2__/graphics/icons/manager-toolbar-white.png",
		icon_size = 32,
		small_icon_size = 32,
		toggleable = true,
		action = "lua",
		style = "blue",
		associated_control_input = "cybersyn2-manager-keybind",
	},
})
