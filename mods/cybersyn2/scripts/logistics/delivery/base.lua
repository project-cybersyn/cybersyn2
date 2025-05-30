--------------------------------------------------------------------------------
-- Delivery abstraction
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local StateMachine = require("__cybersyn2__.lib.state-machine")
local counters = require("__cybersyn2__.lib.counters")
local stlib = require("__cybersyn2__.lib.strace")
local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

local strace = stlib.strace
local WARN = stlib.WARN

---@class Cybersyn.Delivery: StateMachine
local Delivery = class("Delivery", StateMachine)
_G.cs2.Delivery = Delivery

---Create a new delivery object. No creation events are fired; that is
---delegated to the specific delivery lifecycle management.
---@param type string
---@return Cybersyn.Delivery
function Delivery.new(type)
	local id = counters.next("delivery")
	storage.deliveries[id] = setmetatable({
		id = id,
		type = type, -- default type
		created_tick = game.tick,
		state_tick = game.tick,
		state = "init",
	}, Delivery)
	return storage.deliveries[id]
end

---Retrieve a delivery state from storage
---@param id Id?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.Delivery?
local function get_delivery(id, skip_validation)
	if not id then return nil end
	local x = storage.deliveries[id]
	if skip_validation then
		return x
	elseif x then
		return x:is_valid() and x or nil
	end
end
Delivery.get = get_delivery
_G.cs2.get_delivery = get_delivery

function Delivery:destroy()
	local id = self.id
	local delivery = storage.deliveries[id]
	if not delivery then return end
	delivery.is_being_destroyed = true
	cs2.raise_delivery_destroyed(delivery)
	storage.deliveries[id] = nil
end

---Fail this delivery.
function Delivery:fail(reason)
	if self.state == "completed" or self.state == "failed" then
		strace(
			WARN,
			"delivery",
			self,
			"message",
			"Attempt to fail a delivery that is already completed or failed"
		)
		return
	else
		self:set_state("failed")
	end
end

function Delivery:is_valid()
	-- TODO: stronger validity check here. if vehicle assigned, make sure
	-- it's valid and still thinks it's on this delivery, etc.
	return not self.is_being_destroyed
end

function Delivery:can_change_state(new_state, old_state)
	if new_state == "init" then
		strace(
			WARN,
			"message",
			"Attempt to return delivery to Initializing state",
			self
		)
		return false
	end
	if old_state == "completed" or old_state == "failed" then
		strace(
			WARN,
			"message",
			"Attempt to take delivery out of Completed state",
			self
		)
		return false
	end
	return true
end

function Delivery:on_changed_state(new_state, old_state)
	self.state_tick = game.tick
	StateMachine.on_changed_state(self, new_state, old_state)
	cs2.raise_delivery_state_changed(self, new_state, old_state)
end

function Delivery:is_in_final_state()
	return self.state == "completed" or self.state == "failed"
end

--------------------------------------------------------------------------------
-- Delivery monitor thread
--------------------------------------------------------------------------------

---@class Cybersyn.Internal.DeliveryMonitor: StatefulThread
---@field state "init"|"enum_deliveries" State of the task.
---@field delivery_ids Id[] Extant Cybersyn delivery IDs at beginning of sweep.
local DeliveryMonitor = class("DeliveryMonitor", cs2.StatefulThread)

function DeliveryMonitor.new()
	local thread = setmetatable({}, DeliveryMonitor) --[[@as Cybersyn.Internal.DeliveryMonitor]]
	thread:set_state("init")
	return thread
end

function DeliveryMonitor:init()
	if game then self:set_state("enum_deliveries") end
end

function DeliveryMonitor:enter_enum_deliveries()
	self.stride =
		math.ceil(cs2.PERF_DELIVERY_MONITOR_WORKLOAD * mod_settings.work_factor)
	self.index = 1
	self.delivery_ids = tlib.keys(storage.deliveries)
end

function DeliveryMonitor:enum_delivery(delivery_id)
	local delivery = get_delivery(delivery_id, true)
	if not delivery then return end
	-- Destroy expired deliveries.
	if
		delivery:is_in_final_state()
		and (
			not delivery.state_tick
			or delivery.state_tick < game.tick - cs2.DELIVERY_EXPIRATION_TICKS
		)
	then
		return delivery:destroy()
	end
end

function DeliveryMonitor:enum_deliveries()
	self:async_loop(
		self.delivery_ids,
		self.enum_delivery,
		function(thr) thr:set_state("init") end
	)
end

function DeliveryMonitor:exit_enum_deliveries() self.delivery_ids = nil end

cs2.schedule_thread(
	"delivery_monitor",
	2,
	function() return DeliveryMonitor.new() end
)
