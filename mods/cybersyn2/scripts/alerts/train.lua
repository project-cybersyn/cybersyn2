--------------------------------------------------------------------------------
-- Alerts relating to trains
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local stlib = require("lib.core.strace")
local event = require("lib.core.event")
local poslib = require("lib.core.math.pos")

local cs2 = _G.cs2

--------------------------------------------------------------------------------
-- Misdirected train
--------------------------------------------------------------------------------

---@class Cybersyn.Alert.MisdirectedTrain : Cybersyn.GameAlert
---@field public cstrain Cybersyn.Train
---@field public delivery_id Id?
local MisdirectedTrain = class("Alert.MisdirectedTrain", cs2.GameAlert)

local MISDIRECTED_TRAIN_MSG = { "cybersyn2-alerts.misdirected-train" }

---@param cstrain Cybersyn.Train
function MisdirectedTrain:new(cstrain)
	local entity = cstrain:get_stock()
	if not entity then return nil end
	local alert = cs2.GameAlert.new(
		self,
		entity,
		"misdirected_train",
		MISDIRECTED_TRAIN_MSG,
		cs2.CS2_ICON_SIGNAL_ID
	) --[[@as Cybersyn.Alert.MisdirectedTrain]]
	if alert then
		alert.cstrain = cstrain
		alert.delivery_id = cstrain.delivery_id
		alert:show(true)
		return alert
	end
end

function MisdirectedTrain:should_persist()
	local train = self.cstrain
	if (not train) or (not train:is_valid()) then return false end
	if (not self.delivery_id) or (train.delivery_id ~= self.delivery_id) then
		return false
	end
	local delivery = cs2.get_delivery(self.delivery_id)
	if (not delivery) or delivery:is_in_final_state() then return false end
	return true
end

event.bind(
	"cs2.alert.misdirected_train",
	function(cstrain) MisdirectedTrain:new(cstrain) end
)

--------------------------------------------------------------------------------
-- Stuck train
--------------------------------------------------------------------------------

---@class Cybersyn.Alert.StuckTrain : Cybersyn.GameAlert
---@field public delivery_id Id The ID of the delivery associated with the stuck train.
---@field public stock LuaEntity The rolling stock whose position was measured.
---@field public stuck_pos MapPosition The position where the train is stuck.
---@field public stuck_state string Delivery state where the train is stuck.
local StuckTrain = class("Alert.StuckTrain", cs2.GameAlert)

local STUCK_TRAIN_MSG = { "cybersyn2-alerts.stuck-train" }

---@param delivery_id Id
---@param stock LuaEntity
---@param stuck_pos MapPosition
---@param stuck_state string
function StuckTrain:new(delivery_id, stock, stuck_pos, stuck_state)
	local alert = cs2.GameAlert.new(
		self,
		stock,
		"stuck_train",
		STUCK_TRAIN_MSG,
		cs2.CS2_ICON_SIGNAL_ID
	) --[[@as Cybersyn.Alert.StuckTrain]]
	if alert then
		alert.delivery_id = delivery_id
		alert.stock = stock
		alert.stuck_pos = stuck_pos
		alert.stuck_state = stuck_state
		alert:show(true)
		return alert
	end
end

-- Stuck train alerts persist until the train moves significantly or the delivery completes or changes state.
function StuckTrain:should_persist()
	local delivery = cs2.get_delivery(self.delivery_id)
	-- If delivery has completed or changed state, no longer stuck.
	if (not delivery) or delivery:is_in_final_state() then return false end
	if delivery.state ~= self.stuck_state then return false end
	if (not self.stock) or not self.stock.valid then return false end
	-- If delivery has moved considerably, no longer stuck.
	local distsq = poslib.pos_distsq(self.stock.position, self.stuck_pos)
	if distsq >= 4 then return false end
	return true
end

event.bind(
	"cs2.train_stuck",
	function(delivery_id, cstrain, stock, stuck_pos, stuck_state)
		StuckTrain:new(delivery_id, stock, stuck_pos, stuck_state)
	end
)
