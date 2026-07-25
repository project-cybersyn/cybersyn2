--------------------------------------------------------------------------------
-- Alert subsystem
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local stlib = require("lib.core.strace")
local counters = require("lib.core.counters")
local scheduler = require("lib.core.scheduler")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local cs2 = _G.cs2

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

local next = next
local pairs = pairs

local ALERT_RESHOW_TICKS = 478 -- Factorio's engine expires custom alerts every 480 ticks, so we reshow slightly before that to ensure they persist.

---A generic alert.
---@class Cybersyn.Alert
---@field public id Id Unique identifier for the alert
---@field public message? LocalisedString User-facing message for the alert.
---@field public expires? uint Tick when alert expires, if given
local Alert = class("Alert")
cs2.Alert = Alert

function Alert:new()
	---@type Cybersyn.Alert
	local alert = setmetatable({ id = counters.next("alert") }, self)
	storage.alerts[alert.id] = alert
	return alert
end

---Determine if the condition causing this alert is still present.
---@return boolean
function Alert:should_persist() return true end

---Destroy the alert.
function Alert:destroy() storage.alerts[self.id] = nil end

--------------------------------------------------------------------------------
-- GameAlert
--------------------------------------------------------------------------------

---A Factorio in-game custom alert attached to an entity.
---@class Cybersyn.GameAlert : Cybersyn.Alert
---@field public key? string If given, enforced uniquely per entity.
---@field public entity LuaEntity Entity this alert is attached to.
---@field public unit_number UnitNumber Unit number of entity this alert is attached to.
---@field public icon SignalID Icon for the alert
---@field public players LuaPlayer[] Players who should see the alert
---@field public reshow_task_id? uint If the alert is scheduled to be re-shown, the ID of the scheduled task.
local GameAlert = class("GameAlert", Alert)
cs2.GameAlert = GameAlert

---Create a new alert attached to an entity.
---@param entity LuaEntity? Entity to attach the alert to
---@param key string? Unique key for the alert. Only one alert with this key will be allowed per entity.
---@param icon SignalID Icon for the alert.
---@param message LocalisedString User-facing message for the alert.
---@param players (LuaPlayer[])? List of players who should see the alert. Defaults to all players on the entity's force.
---@return Cybersyn.Alert|nil alert The alert object, or nil if it can't be created.
function GameAlert:new(entity, key, message, icon, players)
	-- Early-out cases: Invalidity
	if not entity or not entity.valid then return end

	-- Uniqueness
	local abe = storage.alerts_by_entity[
		entity.unit_number --[[@as UnitNumber]]
	]
	if abe then
		if key and abe[key] then return end
	end

	-- Visibility
	if not players then players = entity.force.players end
	if #players == 0 then return end -- Don't create alerts that no one can see

	if not abe then
		abe = {}
		storage.alerts_by_entity[
			entity.unit_number --[[@as UnitNumber]]
		] =
			abe
	end

	local alert = Alert.new(self) --[[@as Cybersyn.GameAlert]]

	alert.key = key
	alert.entity = entity
	alert.unit_number = entity.unit_number
	alert.icon = icon
	alert.message = { "", message, " (", alert.id, ")" } -- Ensure uniqueness of the alert message to prevent Factorio from merging it with other alerts with the same message.
	alert.players = players

	if key then abe[key] = alert.id end
	return alert
end

---Show the alert to all target players.
---@param schedule_reshow boolean If true, schedules the alert to be re-shown at its Factorio engine expirty time.
function GameAlert:show(schedule_reshow)
	local players = self.players
	if (not self.entity.valid) or (not next(players)) then
		return self:destroy()
	end
	self:unshow()
	for _, player in pairs(players) do
		if player.valid then
			player.add_custom_alert(self.entity, self.icon, self.message, true)
		end
	end
	if schedule_reshow and not self.reshow_task_id then
		self.reshow_task_id =
			scheduler.call_method_at(game.tick + ALERT_RESHOW_TICKS, self, "reshow")
	end
end

---Remove the alert from all target players.
function GameAlert:unshow()
	local players = self.players
	if not next(players) then return end
	local existing_alert = {
		entity = self.entity,
		type = defines.alert_type.custom,
		message = self.message,
	}
	for _, player in pairs(players) do
		if player.valid then player.remove_alert(existing_alert) end
	end
end

---Reshow an alert when factorio's engine expires it. Should be called by the scheduler, not manually.
function GameAlert:reshow()
	self.reshow_task_id = nil
	if not self:should_persist() then return self:destroy() end
	self:show(true)
end

---Destroy the alert and remove it from all players' displays.
function GameAlert:destroy()
	self.players = tlib.EMPTY
	if self.reshow_task_id then
		scheduler.stop(self.reshow_task_id)
		self.reshow_task_id = nil
	end
	self:unshow()
	storage.alerts[self.id] = nil
	local abe = storage.alerts_by_entity[self.unit_number]
	if abe and self.key then
		abe[self.key] = nil
		if not next(abe) then storage.alerts_by_entity[self.unit_number] = nil end
	end
end

--------------------------------------------------------------------------------
-- Global API
--------------------------------------------------------------------------------

---Get an alert by id
---@param id Id id of the alert to retrieve
---@return Cybersyn.Alert? alert The alert with the given id, or nil if it doesn't exist
function cs2.get_alert(id) return storage.alerts and storage.alerts[id] end

---Get all alerts targeting the given entity.
---@param entity LuaEntity The entity whose alerts should be retrieved.
---@return Cybersyn.Alert[] alerts List of alerts targeting the entity.
function cs2.get_alerts_for_entity(entity)
	local abe = storage.alerts_by_entity
		and storage.alerts_by_entity[
			entity.unit_number --[[@as UnitNumber]]
		]
	if not abe then return {} end
	return tlib.t_map_a(abe, function(_, id)
		local alert = storage.alerts and storage.alerts[id]
		return alert
	end)
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

events.bind("on_shutdown", function()
	-- Clear all alerts on shutdown
	if storage.alerts then
		for _, alert in pairs(storage.alerts) do
			alert:destroy()
		end
	end
end)

-- Legacy/migration: prevent crashes from old lingering alerts.
scheduler.register_handler(
	"alert_handler",
	function() return scheduler.ABORT end
)
