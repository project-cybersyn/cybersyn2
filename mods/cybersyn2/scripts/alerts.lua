local counters = require("lib.core.counters")
local scheduler = require("lib.core.scheduler")
local tlib = require("lib.core.table")
local cs2 = _G.cs2

---@class Cybersyn.Alert
---@field public id Id Unique identifier for the alert
---@field public key string Unique key per entity, used to stop a single alert showing multiple times per entity.
---@field public entity LuaEntity Entity this alert is attached to.
---@field public unit_number UnitNumber Unit number of entity this alert is attached to.
---@field public icon? SignalID Icon for the alert
---@field public message? LocalisedString Message to display in the alert
---@field public players IdSet Players who should see the alert
---@field public expires? uint Tick when alert expires and should not be re-shown.

---@param entity LuaEntity Entity to attach the alert to
---@param key string Unique key for the alert, used to prevent multiple alerts from showing for the same entity.
---@return Cybersyn.Alert|nil alert The alert object, or nil if it can't be created.
local function create_alert(entity, key)
	if not entity or not entity.valid then return end
	-- XXX: remove nil checks for release, should be handled by on_init
	if not storage.alerts then storage.alerts = {} end
	if not storage.alerts_by_entity then storage.alerts_by_entity = {} end
	local abe = storage.alerts_by_entity[entity.unit_number]
	if abe then
		if abe[key] then return end
	else
		abe = {}
		storage.alerts_by_entity[entity.unit_number] = abe
	end
	local id = counters.next("alert")
	local alert = {
		id = id,
		key = key,
		entity = entity,
		unit_number = entity.unit_number,
		icon = nil,
		message = nil,
		players = {},
	}
	storage.alerts[id] = alert
	abe[key] = id
	return alert
end

local function get_alert_for_entity(unit_number, key)
	-- XXX: remove nil checks for release, should be handled by on_init
	local abe = storage.alerts_by_entity and storage.alerts_by_entity[unit_number]
	if not abe then return end
	local id = abe[key]
	if not id then return end
	return storage.alerts and storage.alerts[id]
end

local function destroy_alert(id, remove_from_display)
	-- XXX: remove nil checks for release, should be handled by on_init
	local alert = storage.alerts and storage.alerts[id]
	if not alert then return end
	storage.alerts[id] = nil
	local abe = storage.alerts_by_entity[alert.unit_number]
	if not abe then return end
	abe[alert.key] = nil
	if not next(abe) then storage.alerts_by_entity[alert.unit_number] = nil end
	if remove_from_display then
		for player_id in pairs(alert.players) do
			local p = game.get_player(player_id)
			if p and p.valid then
				p.remove_alert({
					entity = alert.entity,
					type = defines.alert_type.custom,
					message = alert.message,
				})
			end
		end
	end
end

scheduler.register_handler("alert_handler", function(task)
	local alert_id = task.data
	if not alert_id then return end
	-- XXX: remove nil checks for release, should be handled by on_init
	local alert = storage.alerts and storage.alerts[alert_id]
	if not alert or not alert.entity or not alert.entity.valid then
		return destroy_alert(alert_id)
	end
	if alert.expires and alert.expires < game.tick then
		return destroy_alert(alert_id)
	end
	-- If no players are left, remove the alert
	if not next(alert.players) then return destroy_alert(alert_id) end
	-- Otherwise, destroy and recreate the alert for all remaining players.
	for player_index in pairs(alert.players) do
		local player = game.get_player(player_index)
		if player and player.valid then
			player.remove_alert({
				entity = alert.entity,
				type = defines.alert_type.custom,
				message = alert.message,
			})
			player.add_custom_alert(alert.entity, alert.icon, alert.message, true)
		end
	end
	-- Reschedule the alert check for the tick when it would disappear
	scheduler.at(game.tick + 478, "alert_handler", alert.id)
end)

---@param target_entity LuaEntity Entity to attach the alert to
---@param key string Unique key for the alert, used to prevent multiple alerts from showing for the same entity.
---@param icon SignalID Icon for the alert
---@param message LocalisedString Message to display in the alert
---@param duration uint? Duration of the alert in ticks, or nil for no expiration.
function _G.cs2.create_alert(target_entity, key, icon, message, duration)
	if not target_entity or not target_entity.valid then return end
	local alert = create_alert(target_entity, key)
	if not alert then return end

	local players = target_entity.force.players
	local player_ids = tlib.t_map_t(
		players,
		function(_, x) return x.index, true end
	)
	alert.icon = icon
	alert.message = message
	alert.players = player_ids
	if duration then alert.expires = game.tick + duration end

	for _, player in pairs(players) do
		player.add_custom_alert(target_entity, icon, message, true)
	end

	scheduler.at(game.tick + 478, "alert_handler", alert.id)
end

function _G.cs2.destroy_alert(target_entity, key)
	if not target_entity or not target_entity.valid then return end
	local alert = get_alert_for_entity(target_entity.unit_number, key)
	if not alert then return end
	destroy_alert(alert.id, true)
end

---Destroy all alerts for a given entity.
---@param target_entity LuaEntity Entity to destroy alerts for
function _G.cs2.destroy_alerts(target_entity)
	if not target_entity or not target_entity.valid then return end
	local abe = storage.alerts_by_entity
		and storage.alerts_by_entity[target_entity.unit_number]
	if not abe then return end
	for _, id in pairs(abe) do
		destroy_alert(id, true)
	end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

cs2.on_reset(function()
	-- Clear all alerts on reset
	if storage.alerts then
		for id in pairs(storage.alerts) do
			destroy_alert(id, true)
		end
	end
end)
