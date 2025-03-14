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
combinator_entity.energy_source = { type = "void" }
combinator_entity.active_energy_usage = "1W"
local flags = combinator_entity.flags or {}
table.insert(flags, "get-by-unit-number")
combinator_entity.flags = flags

---@type data.DisplayPanelPrototype
combinator_settings_entity = flib.copy_prototype(data.raw["display-panel"]["display-panel"],
	"cybersyn2-combinator-settings")
combinator_settings_entity.icon = nil
combinator_settings_entity.icon_size = nil
combinator_settings_entity.next_upgrade = nil
combinator_settings_entity.minable = nil
combinator_settings_entity.selection_box = nil
combinator_settings_entity.collision_box = nil
combinator_settings_entity.collision_mask = { layers = {} }
-- TODO: hide-in-alt-mode? not-on-map?
combinator_settings_entity.flags = { "not-deconstructable", "not-upgradable", "placeable-off-grid", "not-in-made-in" }
combinator_settings_entity.hidden_in_factoriopedia = true
