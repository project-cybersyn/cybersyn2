local data_lib = require("lib.core.data-util")

---@type data.RecipePrototype
local combinator_recipe = data_lib.copy_prototype(
	data.raw["recipe"]["decider-combinator"],
	"cybersyn2-combinator"
)
combinator_recipe.subgroup = data.raw["recipe"]["train-stop"].subgroup

data:extend({ combinator_recipe })

data_lib.unlock_recipe_with_technology(
	"cybersyn2-combinator",
	"automated-rail-transportation"
)
