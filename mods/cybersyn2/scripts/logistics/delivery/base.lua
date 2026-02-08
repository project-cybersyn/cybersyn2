--------------------------------------------------------------------------------
-- Delivery abstraction
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local StateMachine = require("lib.core.state-machine")
local counters = require("lib.core.counters")
local stlib = require("lib.core.strace")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local thread_lib = require("lib.core.thread")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

local strace = stlib.strace
local WARN = stlib.WARN
local add_workload = thread_lib.add_workload

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
	events.raise("cs2.delivery_state_changed", self, new_state, old_state)
end

function Delivery:is_in_final_state()
	return self.state == "completed" or self.state == "failed"
end

---Determine if this delivery is in a state where it is validly waiting for
---another world event (e.g. a queue slot to empty.)
function Delivery:is_in_wait_state() return false end

---Determine if a delivery should be considered stuck and alert or handle
---accordingly. Called by the monitor thread periodically.
---@param workload Core.Thread.Workload?
function Delivery:check_stuck(workload) end

---Determine if a delivery is cancellable by the user. This gates whether the "Cancel Delivery" button appears.
---@return boolean
function Delivery:is_cancellable() return false end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

cs2.on_vehicle_destroyed(function(vehicle)
	local delivery = get_delivery(vehicle.delivery_id, true)
	if delivery then delivery:fail("vehicle_destroyed") end
end)

events.bind(
	"on_try_shutdown",
	---@param state Core.ResetData
	function(state)
		for _, delivery in pairs(storage.deliveries) do
			if not delivery:is_in_final_state() and state.veto_shutdown then
				table.insert(
					state.veto_shutdown,
					"Shutdown not recommended while deliveries are in progress. Disable logistics in game settings and wait for all vehicles to be idle."
				)
				return
			end
		end
	end
)

--------------------------------------------------------------------------------
-- Delivery monitor thread
--
-- Clears expired completed deliveries from storage and warns about deliveries
-- that may be taking too long to complete.
--------------------------------------------------------------------------------

---@class Cybersyn.Internal.DeliveryMonitor: StatefulThread
---@field state "init"|"enum_deliveries" State of the task.
local DeliveryMonitor = class("DeliveryMonitor", cs2.StatefulThread)

function DeliveryMonitor:new()
	local thread = cs2.StatefulThread.new(self) --[[@as Cybersyn.Internal.DeliveryMonitor]]
	thread.friendly_name = "delivery_monitor"
	thread:set_state("init")
	thread:wake()
	return thread
end

function DeliveryMonitor:init()
	if game then self:set_state("enum_deliveries") end
end

function DeliveryMonitor:enter_enum_deliveries()
	self:begin_async_loop(tlib.keys(storage.deliveries), 1)
	for _, view in pairs(storage.views) do
		view:enter_deliveries(self.workload_counter)
	end
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

	-- Check stuck deliveries
	delivery:check_stuck(self.workload_counter)

	for _, view in pairs(storage.views) do
		view:enter_delivery(self.workload_counter, delivery)
		view:exit_delivery(self.workload_counter, delivery)
	end
	add_workload(self.workload_counter, 2)
end

function DeliveryMonitor:enum_deliveries()
	self:step_async_loop(
		self.enum_delivery,
		function(thr) thr:set_state("init") end
	)
end

function DeliveryMonitor:exit_enum_deliveries()
	self.delivery_ids = nil

	for _, view in pairs(storage.views) do
		view:exit_deliveries(self.workload_counter)
	end
end

-- Start delivery monitor thread on startup.
events.bind("on_startup", function() DeliveryMonitor:new() end)
