local mgr = _G.mgr

---@class (exact) Cybersyn.Manager.ModSettings
---@field public work_period uint Number of ticks between work cycles.
---@field public work_factor number Multiplier applied to work done per cycle.

---@type Cybersyn.Manager.ModSettings
---@diagnostic disable-next-line: missing-fields
_G.mgr.mod_settings = {}
local mod_settings = _G.mgr.mod_settings

local function update_mod_settings() end

-- Initial loading of settings
update_mod_settings()

-- On init we must treat settings as having been changed
mgr.on_init(function() mgr.raise_mod_settings_changed(nil) end)

---@param event EventData.on_runtime_mod_setting_changed
function _G.mgr.handle_runtime_mod_setting_changed(event)
	update_mod_settings()
	mgr.raise_mod_settings_changed(event.setting)
end
