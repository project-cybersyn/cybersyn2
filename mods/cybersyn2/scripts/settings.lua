local cs2 = _G.cs2

local events = require("lib.core.event")
local strace = require("lib.core.strace")

---@class (exact) Cybersyn.ModSettings
---@field public enable_logistics boolean Enable or disable scheduling globally.
---@field public debug boolean Enable debug mode.
---@field public debug_level string Debug level ("NONE", "INFO", "TRACE").
---@field public work_period uint Number of ticks between work cycles.
---@field public work_factor number Multiplier applied to work done per cycle.
---@field public warmup_time number Warmup time in seconds.
---@field public vehicle_warmup_time number Warmup time in seconds for vehicles.
---@field public queue_limit uint Max trains in a queue, beyond local train limit.
---@field public excess_delivery_limit uint Max global deliveries that may address a station, beyond its local train limit.
---@field public default_auto_threshold_fraction number Default depletion threshold for trains, expressed as a fraction (0.0 to 1.0).
---@field public default_train_fullness_fraction number Default train fullness threshold for deliveries, expressed as a fraction (0.0 to 1.0).
---@field public default_netmask int32 Default netmask.

---@type Cybersyn.ModSettings
---@diagnostic disable-next-line: missing-fields
local mod_settings = {}

_G.cs2.mod_settings = mod_settings

---Reload mod settings table from Factorio settings.
local function update_mod_settings()
	mod_settings.enable_logistics =
		settings.global["cybersyn2-setting-enable-logistics"].value --[[@as boolean]]
	local debug_level = settings.global["cybersyn2-setting-debug-level"].value --[[@as string]]
	mod_settings.debug = debug_level ~= "NONE"
	mod_settings.debug_level = debug_level
	mod_settings.work_period =
		settings.startup["cybersyn2-setting-work-period"].value --[[@as uint]]
	mod_settings.work_factor =
		settings.global["cybersyn2-setting-work-factor"].value --[[@as number]]
	mod_settings.warmup_time =
		settings.global["cybersyn2-setting-warmup-time"].value --[[@as number]]
	mod_settings.vehicle_warmup_time =
		settings.global["cybersyn2-setting-vehicle-warmup-time"].value --[[@as number]]
	mod_settings.queue_limit =
		settings.global["cybersyn2-setting-queue-limit"].value --[[@as uint]]
	mod_settings.excess_delivery_limit =
		settings.global["cybersyn2-setting-excess-delivery-limit"].value --[[@as uint]]
	mod_settings.default_auto_threshold_fraction = settings.global["cybersyn2-setting-default-auto-threshold-percent"].value --[[@as uint]]
		/ 100.0
	mod_settings.default_train_fullness_fraction = settings.global["cybersyn2-setting-default-train-fullness-percent"].value --[[@as uint]]
		/ 100.0
	mod_settings.default_netmask =
		settings.global["cybersyn2-setting-default-netmask"].value --[[@as int32]]
end
_G.cs2.update_mod_settings = update_mod_settings

-- Initial loading of settings
update_mod_settings()

-- On init we must treat settings as having been changed
events.bind("on_startup", function()
	cs2.raise_mod_settings_changed(nil)
	events.raise("cs2.mod_settings_changed", nil)
end)

-- Change settings when settings change
events.bind(defines.events.on_runtime_mod_setting_changed, function(event)
	update_mod_settings()
	cs2.raise_mod_settings_changed(event.setting)
	events.raise("cs2.mod_settings_changed", event.setting)
end)

-- Update debug log level when settings change
-- TODO: find a better home for this...
events.bind("cs2.mod_settings_changed", function(setting_name)
	if setting_name == nil or setting_name == "cybersyn2-setting-debug-level" then
		local debug_level = mod_settings.debug_level
		if debug_level == "NONE" then
			storage._LOG_LEVEL = 50
			strace.warn("Log level set to WARN")
		elseif debug_level == "INFO" then
			storage._LOG_LEVEL = 30
			strace.warn("Log level set to INFO")
		elseif debug_level == "TRACE" then
			storage._LOG_LEVEL = 1
			strace.warn("Log level set to ALL")
		end
	end
end)
