local flib = require("__flib__.data-util")

--------------------------------------------------------------------------------
-- Combinator
--------------------------------------------------------------------------------

---@type data.ConstantCombinatorPrototype
local combinator_entity = flib.copy_prototype(
	data.raw["constant-combinator"]["constant-combinator"],
	"cybersyn2-combinator"
)
combinator_entity.radius_visualisation_specification = {
	sprite = {
		filename = "__cybersyn2__/graphics/white.png",
		tint = { r = 1, g = 1, b = 0, a = 0.5 },
		height = 64,
		width = 64,
	},
	distance = 1.5,
}
combinator_entity.minable =
	{ mining_time = 0.1, result = "cybersyn2-combinator" }
combinator_entity.fast_replaceable_group = "cybersyn2-combinator"
local flags = combinator_entity.flags or {}
table.insert(flags, "get-by-unit-number")
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
