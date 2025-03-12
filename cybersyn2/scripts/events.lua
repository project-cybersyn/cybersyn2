local event = require("__cybersyn2__.lib.events").create_event

---Event corresponding to Factorio's `on_init`.
on_init, raise_init = event("init", "nil", "nil", "nil", "nil", "nil")

---Event corresponding to Factorio's `on_configuration_changed`.
on_configuration_changed, raise_configuration_changed = event("configuration_changed", "ConfigurationChangedData", "nil",
	"nil", "nil", "nil")

---Event raised when runtime mod settings are changed. By the time this
---event is dispatched, the global `mod_settings` contains the new settings.
--- * Arg 1 - string - The name of the setting that was changed, or `nil` if unknown.
on_mod_settings_changed, raise_mod_settings_changed = event("mod_settings_changed", "string", "nil",
	"nil", "nil", "nil")
