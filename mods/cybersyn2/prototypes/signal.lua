data:extend({
	{
		type = "item-subgroup",
		name = "cybersyn2-signals",
		group = "signals",
		order = "f",
	},

	{
		type = "virtual-signal",
		name = "cybersyn2-group",
		icon = "__cybersyn2__/graphics/icons/group-signal.png",
		icon_size = 64,
		subgroup = "cybersyn2-signals",
		order = "a",
	},

	{
		type = "virtual-signal",
		name = "cybersyn2-priority",
		icon = "__cybersyn2__/graphics/icons/priority.png",
		icon_size = 64,
		subgroup = "cybersyn2-signals",
		order = "b",
	},

	{
		type = "virtual-signal",
		name = "cybersyn2-item-threshold",
		icon = "__cybersyn2__/graphics/icons/item-threshold.png",
		icon_size = 64,
		subgroup = "cybersyn2-signals",
		order = "c",
	},

	fluid_threshold_signal = {
		type = "virtual-signal",
		name = "cybersyn2-fluid-threshold",
		icon = "__cybersyn2__/graphics/icons/fluid-threshold.png",
		icon_size = 64,
		subgroup = "cybersyn2-signals",
		order = "d",
	},

	item_slots_signal = {
		type = "virtual-signal",
		name = "cybersyn2-item-slots",
		icon = "__cybersyn2__/graphics/icons/item-slots.png",
		icon_size = 64,
		subgroup = "cybersyn2-signals",
		order = "e",
	},

	fluid_capacity_signal = {
		type = "virtual-signal",
		name = "cybersyn2-fluid-capacity",
		icon = "__cybersyn2__/graphics/icons/fluid-capacity.png",
		icon_size = 64,
		subgroup = "cybersyn2-signals",
		order = "f",
	},
})
