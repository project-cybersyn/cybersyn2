---@class (exact) Cybersyn.ModSettings
---@field public enable_logistics boolean Enable or disable scheduling globally.

---@type Cybersyn.ModSettings
---@diagnostic disable-next-line: missing-fields
mod_settings = {}

local function update_mod_settings()
	mod_settings.enable_logistics = settings.global["cybersyn2-setting-enable-logistics"].value
end

-- Initial loading of settings
update_mod_settings()

---@param event EventData.on_runtime_mod_setting_changed
function handle_runtime_mod_setting_changed(event)
	update_mod_settings()
	raise_mod_settings_changed(event.setting)
end
