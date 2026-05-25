--------------------------------------------------------------------------------
-- Alerts relating to train stations and combinators.
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local stlib = require("lib.core.strace")
local event = require("lib.core.event")

local cs2 = _G.cs2

--------------------------------------------------------------------------------
-- No station combinator
--------------------------------------------------------------------------------

---@class Cybersyn.Alert.NoStationComb : Cybersyn.GameAlert
---@field public stop Cybersyn.TrainStop The train stop associated with this alert.
local NoStationComb = class("Alert.NoStationComb", cs2.GameAlert)

local NO_STATION_MSG = { "cybersyn2-alerts.no-station" }

---@param stop Cybersyn.TrainStop
function NoStationComb:new(stop)
	local alert = cs2.GameAlert.new(
		self,
		stop.entity,
		"no_station",
		NO_STATION_MSG,
		cs2.CS2_ICON_SIGNAL_ID
	) --[[@as Cybersyn.Alert.NoStationComb]]
	if alert then
		alert.stop = stop
		alert:show(true)
		return alert
	end
end

function NoStationComb:should_persist()
	if not self.stop:is_valid() then return false end
	local stations = self.stop:get_associated_combinators(
		function(comb) return comb.mode == "station" end
	)
	if #stations == 0 then return true end
	return false
end

event.bind(
	"cs2.alert.no_station_comb",
	function(stop) return NoStationComb:new(stop) end
)

--------------------------------------------------------------------------------
-- Too many of some combinator
--------------------------------------------------------------------------------

---@class Cybersyn.Alert.TooManyStationComb : Cybersyn.GameAlert
---@field public stop Cybersyn.TrainStop The train stop associated with this alert.
---@field public mode string The combinator mode that is duplicated.
local TooManyStationComb = class("Alert.TooManyStationComb", cs2.GameAlert)

---@param stop Cybersyn.TrainStop
---@param key string
---@param mode string
---@param msg LocalisedString
function TooManyStationComb:new(stop, key, mode, msg)
	local alert =
		cs2.GameAlert.new(self, stop.entity, key, msg, cs2.CS2_ICON_SIGNAL_ID) --[[@as Cybersyn.Alert.TooManyStationComb]]
	if alert then
		alert.stop = stop
		alert.mode = mode
		alert:show(true)
		return alert
	end
end

function TooManyStationComb:should_persist()
	if not self.stop:is_valid() then return false end
	local mode = self.mode
	local combs = self.stop:get_associated_combinators(
		function(comb) return comb.mode == mode end
	)
	if #combs > 1 then return true end
	return false
end

local TOO_MANY_STATION_MSG = { "cybersyn2-alerts.too-many-station" }
event.bind(
	"cs2.alert.too_many_station_comb",
	function(stop)
		return TooManyStationComb:new(
			stop,
			"too_many_station",
			"station",
			TOO_MANY_STATION_MSG
		)
	end
)

local TOO_MANY_ALLOWLIST_MSG = { "cybersyn2-alerts.too-many-allowlist" }
event.bind(
	"cs2.alert.too_many_allowlist_comb",
	function(stop)
		return TooManyStationComb:new(
			stop,
			"too_many_allow",
			"allow",
			TOO_MANY_ALLOWLIST_MSG
		)
	end
)

--------------------------------------------------------------------------------
-- Deprecated combinator
--------------------------------------------------------------------------------

---@class Cybersyn.Alert.DeprecatedComb : Cybersyn.GameAlert
---@field public comb Cybersyn.Combinator The combinator associated with this alert.
local DeprecatedComb = class("Alert.DeprecatedComb", cs2.GameAlert)

local DEPRECATED_COMB_MSG = { "cybersyn2-alerts.deprecated-combs" }

---@param comb Cybersyn.Combinator
function DeprecatedComb:new(comb)
	local alert = cs2.GameAlert.new(
		self,
		comb.real_entity,
		"deprecated_comb",
		DEPRECATED_COMB_MSG,
		cs2.CS2_ICON_SIGNAL_ID
	) --[[@as Cybersyn.Alert.DeprecatedComb]]
	if alert then
		alert.comb = comb
		alert:show(true)
		return alert
	end
end

function DeprecatedComb:should_persist()
	if not self.comb:is_valid() then return false end
	local mode = cs2.get_combinator_mode(self.comb.mode)
	if mode and mode.deprecated then return true end
	return false
end

event.bind(
	"cs2.alert.deprecated_comb",
	function(comb) return DeprecatedComb:new(comb) end
)

--------------------------------------------------------------------------------
-- Use of vanilla priority
--------------------------------------------------------------------------------

---@class Cybersyn.Alert.VanillaPriority : Cybersyn.GameAlert
---@field public stop_entity LuaEntity The train stop associated with this alert.
local VanillaPriority = class("Alert.VanillaPriority", cs2.GameAlert)

local VANILLA_PRIORITY_MSG = { "cybersyn2-alerts.vanilla-priority" }

---@param stop_entity LuaEntity
function VanillaPriority:new(stop_entity)
	local alert = cs2.GameAlert.new(
		self,
		stop_entity,
		"vanilla_priority",
		VANILLA_PRIORITY_MSG,
		cs2.CS2_ICON_SIGNAL_ID
	) --[[@as Cybersyn.Alert.VanillaPriority]]
	if alert then
		alert.stop_entity = stop_entity
		alert:show(true)
		return alert
	end
end

function VanillaPriority:should_persist()
	if not self.stop_entity or not self.stop_entity.valid then return false end
	if self.stop_entity.train_stop_priority ~= 50 then return true end
	return false
end

event.bind(
	"cs2.alert.vanilla_priority",
	function(stop_entity) return VanillaPriority:new(stop_entity) end
)
