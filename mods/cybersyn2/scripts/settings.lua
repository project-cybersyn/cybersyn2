local cs2 = _G.cs2

---@class (exact) Cybersyn.ModSettings
---@field public enable_logistics boolean Enable or disable scheduling globally.
---@field public debug boolean Enable debug mode.
---@field public work_period uint Number of ticks between work cycles.
---@field public work_factor number Multiplier applied to work done per cycle.
---@field public warmup_time number Warmup time in seconds.
---@field public vehicle_warmup_time number Warmup time in seconds for vehicles.
---@field public queue_limit uint Max trains in a queue, 0 = no limit.

---@type Cybersyn.ModSettings
---@diagnostic disable-next-line: missing-fields
local mod_settings = {}

_G.cs2.mod_settings = mod_settings

---Reload mod settings table from Factorio settings.
local function update_mod_settings()
	mod_settings.enable_logistics =
		settings.global["cybersyn2-setting-enable-logistics"].value --[[@as boolean]]
	mod_settings.debug = settings.global["cybersyn2-setting-debug"].value --[[@as boolean]]
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
end
_G.cs2.update_mod_settings = update_mod_settings

-- Initial loading of settings
update_mod_settings()

-- On init we must treat settings as having been changed
cs2.on_startup(function() cs2.raise_mod_settings_changed(nil) end)
