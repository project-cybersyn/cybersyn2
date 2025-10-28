local events = require("__cybersyn2__.lib.core.event")

local mgr = _G.mgr

---@class (exact) Cybersyn.Manager.ModSettings

---@type Cybersyn.Manager.ModSettings
---@diagnostic disable-next-line: missing-fields
_G.mgr.mod_settings = {}
local mod_settings = _G.mgr.mod_settings

local function update_mod_settings() end

-- Initial loading of settings
update_mod_settings()

-- On init we must treat settings as having been changed
events.bind(
	"on_startup",
	function() events.raise("mgr.on_mod_settings_changed") end
)

events.bind(defines.events.on_runtime_mod_setting_changed, function(event)
	update_mod_settings()
	events.raise("mgr.on_mod_settings_changed", event.setting)
end)
