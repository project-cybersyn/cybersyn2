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

on_game_train_created, raise_game_train_created = event("game_train_created", "EventData_on_train_created", "nil", "nil",
	"nil", "nil")

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
