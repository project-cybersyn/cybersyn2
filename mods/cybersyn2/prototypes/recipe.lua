local flib = require("__flib__.data-util")

---@type data.RecipePrototype
local combinator_recipe = flib.copy_prototype(
	data.raw["recipe"]["decider-combinator"],
	"cybersyn2-combinator"
)
-- TODO: recipe enabled without research for testing, add tech for live
combinator_recipe.enabled = true
combinator_recipe.subgroup = data.raw["recipe"]["train-stop"].subgroup

data:extend({ combinator_recipe })
