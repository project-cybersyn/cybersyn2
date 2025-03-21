local flib = require("__flib__.data-util")

---@type data.DeciderCombinatorPrototype
combinator_entity = flib.copy_prototype(data.raw["decider-combinator"]["decider-combinator"], "cybersyn2-combinator")
combinator_entity.radius_visualisation_specification = {
	sprite = {
		filename = "__cybersyn2__/graphics/white.png",
		tint = { r = 1, g = 1, b = 0, a = .5 },
		height = 64,
		width = 64,
	},
	--offset = {0, .5},
	distance = 1.5,
}
combinator_entity.selection_priority = 100
combinator_entity.energy_source = { type = "void" }
combinator_entity.active_energy_usage = "1W"
local flags = combinator_entity.flags or {}
table.insert(flags, "get-by-unit-number")
combinator_entity.flags = flags
