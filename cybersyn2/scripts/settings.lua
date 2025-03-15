---@class (exact) Cybersyn.ModSettings
---@field public enable_logistics boolean Enable or disable scheduling globally.
---@field public debug boolean Enable debug mode.
---@field public work_period uint Number of ticks between work cycles.
---@field public work_factor number Multiplier applied to work done per cycle.

---@type Cybersyn.ModSettings
---@diagnostic disable-next-line: missing-fields
mod_settings = {}

local function update_mod_settings()
	mod_settings.enable_logistics = settings.global["cybersyn2-setting-enable-logistics"].value --[[@as boolean]]
	mod_settings.debug = settings.global["cybersyn2-setting-debug"].value --[[@as boolean]]
	mod_settings.work_period = settings.global["cybersyn2-setting-work-period"].value --[[@as uint]]
	mod_settings.work_factor = settings.global["cybersyn2-setting-work-factor"].value --[[@as number]]
end

-- Initial loading of settings
update_mod_settings()

-- On init we must treat settings as having been changed
on_init(function() raise_mod_settings_changed(nil) end)

---@param event EventData.on_runtime_mod_setting_changed
function handle_runtime_mod_setting_changed(event)
	update_mod_settings()
	raise_mod_settings_changed(event.setting)
end
