-- Internal event backplane for Cybersyn.

local event = require("__cybersyn2__.lib.events").create_event

-- These type aliases are necessary due to problems in Sumneko Lua's parameter
-- system.

---@alias StringOrNil string|nil

---Event corresponding to Factorio's `on_init`.
on_init, raise_init = event("init", "nil", "nil", "nil", "nil", "nil")

---Event corresponding to Factorio's `on_configuration_changed`.
on_configuration_changed, raise_configuration_changed = event("configuration_changed", "ConfigurationChangedData", "nil",
	"nil", "nil", "nil")

---Event raised when runtime mod settings are changed. By the time this
---event is dispatched, the global `mod_settings` contains the new settings.
--- * Arg 1 - string|nil - The name of the setting that was changed, or `nil` if unknown. When `nil` you must assume any/all settings have changed.
on_mod_settings_changed, raise_mod_settings_changed = event("mod_settings_changed", "StringOrNil", "nil",
	"nil", "nil", "nil")

on_luatrain_created, raise_luatrain_created = event("luatrain_created", "EventData.on_train_created", "nil", "nil",
	"nil", "nil")

on_luatrain_changed_state, raise_luatrain_changed_state = event("luatrain_changed_state",
	"EventData.on_train_changed_state", "nil", "nil", "nil", "nil")

on_vehicle_created, raise_vehicle_created = event("vehicle_created", "Cybersyn.Vehicle", "nil", "nil", "nil", "nil")

on_vehicle_destroyed, raise_vehicle_destroyed = event("vehicle_destroyed", "Cybersyn.Vehicle", "nil", "nil", "nil",
	"nil")

---Event raised when a new Cybersyn train group is created.
on_train_group_created, raise_train_group_created = event("train_group_created", "string",
	"nil", "nil", "nil", "nil")

---Event raised when a train is added to a Cybersyn group.
on_train_group_train_added, raise_train_group_train_added = event("train_group_train_added", "Cybersyn.Train",
	"nil", "nil", "nil", "nil")

---Event raised when a train is removed from a Cybersyn group.
on_train_group_train_removed, raise_train_group_train_removed = event("train_group_train_removed", "Cybersyn.Train",
	"string", "nil", "nil", "nil")

---Event raised when a train group is destroyed.
on_train_group_destroyed, raise_train_group_destroyed = event("train_group_destroyed", "string",
	"nil", "nil", "nil", "nil")

on_built_train_stop, raise_built_train_stop = event("built_train_stop", "LuaEntity", "nil", "nil", "nil", "nil")

on_broken_train_stop, raise_broken_train_stop = event("broken_train_stop", "LuaEntity", "nil", "nil", "nil",
	"nil")

on_built_rail, raise_built_rail = event("built_rail", "LuaEntity", "nil", "nil", "nil", "nil")

on_broken_rail, raise_broken_rail = event("broken_rail", "LuaEntity", "nil", "nil", "nil", "nil")

on_built_combinator, raise_built_combinator = event("built_combinator", "LuaEntity",
	"nil", "nil", "nil", "nil")

on_broken_combinator, raise_broken_combinator = event("broken_combinator", "LuaEntity",
	"nil", "nil", "nil", "nil")

on_built_combinator_ghost, raise_built_combinator_ghost = event("built_combinator_ghost", "LuaEntity",
	"nil", "nil", "nil", "nil")

on_broken_combinator_ghost, raise_broken_combinator_ghost = event("broken_combinator_ghost", "LuaEntity",
	"nil", "nil", "nil", "nil")

on_broken_train_stock, raise_broken_train_stock = event("broken_train_stock", "LuaEntity",
	"LuaTrain", "nil", "nil", "nil")

-- Event raised when a relevant entity changes its physical configuration.
on_entity_repositioned, raise_entity_repositioned = event("entity_repositioned", "string", "LuaEntity",
	"nil", "nil", "nil")

-- Event raised when a relevant entity is renamed.
on_entity_renamed, raise_entity_renamed = event("entity_renamed", "string", "LuaEntity",
	"nil", "nil", "nil")

on_surface_removed, raise_surface_removed = event("surface_removed", "int",
	"nil", "nil", "nil", "nil")

---Event raised when equipment recognized by the layout algorithm is built.
on_built_equipment, raise_built_equipment = event("built_equipment", "LuaEntity",
	"nil", "nil", "nil", "nil")

-- Event raised when equipment recognized by the layout algorithm is removed.
on_broken_equipment, raise_broken_equipment = event("broken_equipment", "LuaEntity",
	"nil", "nil", "nil", "nil")

-- Event raised when an ephemeral combinator has its settings changed,
-- possibly en masse, by a factorio copy and paste or blueprint op.
on_combinator_settings_pasted, raise_combinator_settings_pasted = event("combinator_settings_pasted",
	"Cybersyn.Combinator.Ephemeral", "nil", "nil", "nil", "nil")

---@alias BlueprintEntityArray BlueprintEntity[]

---Event raised when a blueprint is pasted into the world.
on_built_blueprint, raise_built_blueprint = event("built_blueprint",
	"LuaPlayer", "EventData.on_pre_build", "nil", "nil", "nil")
