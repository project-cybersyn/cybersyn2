local flib = require("__flib__.data-util")

--------------------------------------------------------------------------------
-- Combinator
--------------------------------------------------------------------------------

---@type data.DeciderCombinatorPrototype
local combinator_entity = flib.copy_prototype(
	data.raw["decider-combinator"]["decider-combinator"],
	"cybersyn2-combinator"
)
combinator_entity.icon = "__cybersyn2__/graphics/icons/combinator.png"
combinator_entity.radius_visualisation_specification = {
	sprite = {
		filename = "__cybersyn2__/graphics/white.png",
		tint = { r = 1, g = 1, b = 0, a = 0.5 },
		height = 64,
		width = 64,
	},
	distance = 1.5,
}
-- Make combi 1x1
combinator_entity.collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } }
combinator_entity.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
-- Tweak wiring stuff
combinator_entity.output_connection_bounding_box =
	{ { -0.5, -0.49 }, { 0.5, 0.5 } }
combinator_entity.input_connection_bounding_box =
	{ { 0.0, -0.01 }, { 0.0, -0.01 } }
combinator_entity.output_connection_points = {
	{
		shadow = {
			red = util.by_pixel(7, -6),
			green = util.by_pixel(23, -6),
		},
		wire = {
			red = util.by_pixel(-8.5, -17.5),
			green = util.by_pixel(7, -17.5),
		},
	},
	{
		shadow = {
			red = util.by_pixel(32, -5),
			green = util.by_pixel(32, 8),
		},
		wire = {
			red = util.by_pixel(16, -16.5),
			green = util.by_pixel(16, -3.5),
		},
	},
	{
		shadow = {
			red = util.by_pixel(25, 20),
			green = util.by_pixel(9, 20),
		},
		wire = {
			red = util.by_pixel(9, 7.5),
			green = util.by_pixel(-6.5, 7.5),
		},
	},
	{
		shadow = {
			red = util.by_pixel(1, 11),
			green = util.by_pixel(1, -2),
		},
		wire = {
			red = util.by_pixel(-15, -0.5),
			green = util.by_pixel(-15, -13.5),
		},
	},
}
combinator_entity.input_connection_points = {
	{
		shadow = {
			red = util.by_pixel(7, -6),
			green = util.by_pixel(23, -6),
		},
		wire = {
			red = util.by_pixel(-8.5, -17.5),
			green = util.by_pixel(7, -17.5),
		},
	},
	{
		shadow = {
			red = util.by_pixel(32, -5),
			green = util.by_pixel(32, 8),
		},
		wire = {
			red = util.by_pixel(16, -16.5),
			green = util.by_pixel(16, -3.5),
		},
	},
	{
		shadow = {
			red = util.by_pixel(25, 20),
			green = util.by_pixel(9, 20),
		},
		wire = {
			red = util.by_pixel(9, 7.5),
			green = util.by_pixel(-6.5, 7.5),
		},
	},
	{
		shadow = {
			red = util.by_pixel(1, 11),
			green = util.by_pixel(1, -2),
		},
		wire = {
			red = util.by_pixel(-15, -0.5),
			green = util.by_pixel(-15, -13.5),
		},
	},
}
-- End tweak wiring stuff
combinator_entity.energy_source = { type = "void" }
combinator_entity.minable =
	{ mining_time = 0.1, result = "cybersyn2-combinator" }
combinator_entity.fast_replaceable_group = "cybersyn2-combinator"
local flags = combinator_entity.flags or {}
table.insert(flags, "get-by-unit-number")
table.insert(flags, "hide-alt-info")
combinator_entity.flags = flags

---@diagnostic disable-next-line: undefined-global
combinator_entity.sprites = make_4way_animation_from_spritesheet({
	layers = {
		{
			scale = 0.5,
			filename = "__cybersyn2__/graphics/entities/cybernetic-combinator.png",
			width = 114,
			height = 102,
			frame_count = 1,
			shift = util.by_pixel(0, 5),
		},
		{
			scale = 0.5,
			filename = "__cybersyn2__/graphics/entities/cybernetic-combinator-shadow.png",
			width = 98,
			height = 66,
			frame_count = 1,
			shift = util.by_pixel(8.5, 5.5),
			draw_as_shadow = true,
		},
	},
})

data:extend({ combinator_entity })

--------------------------------------------------------------------------------
-- Hidden Output
--------------------------------------------------------------------------------

local combinator_out_entity = flib.copy_prototype(
	data.raw["constant-combinator"]["constant-combinator"],
	"cybersyn2-output"
) --[[@as data.ConstantCombinatorPrototype]]
combinator_out_entity.icon = nil
combinator_out_entity.icon_size = nil
combinator_out_entity.next_upgrade = nil
combinator_out_entity.minable = nil
combinator_out_entity.selection_box = nil
combinator_out_entity.collision_box = nil
combinator_out_entity.collision_mask = { layers = {} }
combinator_out_entity.circuit_wire_max_distance = 3
combinator_out_entity.flags =
	{ "not-blueprintable", "not-deconstructable", "placeable-off-grid" }
combinator_out_entity.hidden_in_factoriopedia = true

local origin = { 0.0, 0.0 }
local invisible_sprite =
	{ filename = "__cybersyn2__/graphics/invisible.png", width = 1, height = 1 }
local wire_con1 = {
	red = origin,
	green = origin,
}
local wire_con0 = { wire = wire_con1, shadow = wire_con1 }
combinator_out_entity.sprites = invisible_sprite
combinator_out_entity.activity_led_sprites = invisible_sprite
combinator_out_entity.activity_led_light = {
	intensity = 0,
	size = 0,
}
combinator_out_entity.activity_led_light_offsets =
	{ origin, origin, origin, origin }
combinator_out_entity.draw_circuit_wires = false
combinator_out_entity.circuit_wire_connection_points = {
	wire_con0,
	wire_con0,
	wire_con0,
	wire_con0,
}

data:extend({ combinator_out_entity })
