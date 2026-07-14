if not mods["nullius"] then return end

-- Item
local item = data.raw["item"]["cybersyn2-combinator"]
item.order = "nullius-eca"

-- Recipe
local recipe = data.raw["recipe"]["cybersyn2-combinator"]
recipe.order = "nullius-eca"
recipe.ingredients = {
	{ type = "item", name = "arithmetic-combinator", amount = 2 },
	{ type = "item", name = "copper-cable", amount = 10 },
}
recipe.categories = { "tiny-crafting" }
recipe.always_show_made_in = true
recipe.energy_required = 3
