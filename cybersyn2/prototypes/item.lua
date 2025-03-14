local flib = require("__flib__.data-util")

---@type data.ItemPrototype
combinator_item = flib.copy_prototype(data.raw["item"]["decider-combinator"], "cybersyn2-combinator")
combinator_item.icon = "__cybersyn2__/graphics/icons/combinator.png"
combinator_item.icon_size = 64
combinator_item.subgroup = data.raw["item"]["train-stop"].subgroup
combinator_item.order = data.raw["item"]["train-stop"].order .. "-b"
combinator_item.place_result = "cybersyn2-combinator"
