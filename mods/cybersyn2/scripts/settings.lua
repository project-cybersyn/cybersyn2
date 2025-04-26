local cs2 = _G.cs2

---@class (exact) Cybersyn.ModSettings
---@field public enable_logistics boolean Enable or disable scheduling globally.
---@field public debug boolean Enable debug mode.
---@field public work_period uint Number of ticks between work cycles.
---@field public work_factor number Multiplier applied to work done per cycle.
---@field public default_channel_mask int Default channel mask.
---@field public default_network_mask int Default network mask.
---@field public warmup_time number Warmup time in seconds.
---@field public queue_limit uint Max trains in a queue, 0 = no limit.

---@type Cybersyn.ModSettings
---@diagnostic disable-next-line: missing-fields
local mod_settings = {}

_G.cs2.mod_settings = mod_settings

local function update_mod_settings()
	mod_settings.enable_logistics =
		settings.global["cybersyn2-setting-enable-logistics"].value --[[@as boolean]]
	mod_settings.debug = settings.global["cybersyn2-setting-debug"].value --[[@as boolean]]
	mod_settings.work_period =
		settings.global["cybersyn2-setting-work-period"].value --[[@as uint]]
	mod_settings.work_factor =
		settings.global["cybersyn2-setting-work-factor"].value --[[@as number]]
	mod_settings.default_channel_mask =
		settings.global["cybersyn2-setting-channel-mask"].value --[[@as int]]
	mod_settings.default_network_mask =
		settings.global["cybersyn2-setting-network-mask"].value --[[@as int]]
	mod_settings.warmup_time =
		settings.global["cybersyn2-setting-warmup-time"].value --[[@as number]]
	mod_settings.queue_limit =
		settings.global["cybersyn2-setting-queue-limit"].value --[[@as uint]]
end

-- Initial loading of settings
update_mod_settings()

-- On init we must treat settings as having been changed
cs2.on_init(function() cs2.raise_mod_settings_changed(nil) end)

---@param event EventData.on_runtime_mod_setting_changed
function _G.cs2.handle_runtime_mod_setting_changed(event)
	update_mod_settings()
	cs2.raise_mod_settings_changed(event.setting)
end
