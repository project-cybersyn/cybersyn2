local flib = require("__flib__.data-util")

---@type data.ItemPrototype
combinator_item = flib.copy_prototype(data.raw["item"]["decider-combinator"], "cybersyn2-combinator")
combinator_item.icon = "__cybersyn2__/graphics/icons/combinator.png"
combinator_item.icon_size = 64
combinator_item.subgroup = data.raw["item"]["train-stop"].subgroup
combinator_item.order = data.raw["item"]["train-stop"].order .. "-b"
combinator_item.place_result = "cybersyn2-combinator"

-- Hidden settings item. Even though it should never be possible for a user
-- to obtain one in normal gameplay, the item must still exist or the settings
-- can't be put in a blueprint.
---@type data.ItemPrototype
combinator_settings_item = flib.copy_prototype(data.raw["item"]["display-panel"], "cybersyn2-combinator-settings")
-- TODO: hidden settings icon is visible in blueprint, add something here
combinator_settings_item.place_result = "cybersyn2-combinator-settings"
combinator_settings_item.hidden = true
combinator_settings_item.hidden_in_factoriopedia = true
