local event = require("__cybersyn2__.lib.events").create_event

--------------------------------------------------------------------------------
-- Factorio core control phase events
--------------------------------------------------------------------------------

_G.mgr.on_init, _G.mgr.raise_init =
	event("init", "nil", "nil", "nil", "nil", "nil")

_G.mgr.on_load, _G.mgr.raise_load =
	event("load", "nil", "nil", "nil", "nil", "nil")

---Event corresponding to Factorio's `on_configuration_changed`.
_G.mgr.on_configuration_changed, _G.mgr.raise_configuration_changed = event(
	"configuration_changed",
	"ConfigurationChangedData",
	"nil",
	"nil",
	"nil",
	"nil"
)

---Event raised when runtime mod settings are changed. By the time this
---event is dispatched, the global `mod_settings` contains the new settings.
--- * Arg 1 - string|nil - The name of the setting that was changed, or `nil` if unknown. When `nil` you must assume any/all settings have changed.
_G.mgr.on_mod_settings_changed, _G.mgr.raise_mod_settings_changed =
	event("mod_settings_changed", "StringOrNil", "nil", "nil", "nil", "nil")

--------------------------------------------------------------------------------
-- Control and input events
--------------------------------------------------------------------------------

_G.mgr.on_inspector_selected, _G.mgr.raise_inspector_selected = event(
	"on_inspector_selected",
	"EventData.on_player_selected_area",
	"nil",
	"nil",
	"nil",
	"nil"
)

_G.mgr.on_manager_toggle, _G.mgr.raise_manager_toggle =
	event("on_manager_toggle", "PlayerIndex", "nil", "nil", "nil", "nil")

--------------------------------------------------------------------------------
-- Cybersyn 2 custom events
--------------------------------------------------------------------------------

_G.mgr.on_view_updated, _G.mgr.raise_view_updated =
	event("view_updated", "Id", "nil", "nil", "nil", "nil")
