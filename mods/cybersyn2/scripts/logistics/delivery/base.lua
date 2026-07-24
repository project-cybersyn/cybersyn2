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
local mod_settings = cs2.mod_settings

local strace = stlib.strace
local WARN = stlib.WARN
local add_workload = thread_lib.add_workload

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

---@class (partial) Cybersyn.Delivery: StateMachine
local Delivery = class("Delivery", StateMachine)
cs2.Delivery = Delivery

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
cs2.get_delivery = get_delivery

function Delivery:destroy()
	local id = self.id
	local delivery = storage.deliveries[id]
	if not delivery then return end
	delivery.is_being_destroyed = true
	events.raise("cs2.delivery_destroyed", delivery)
	storage.deliveries[id] = nil
end

---Fail this delivery.
function Delivery:fail(reason)
	if self.state == "completed" or self.state == "failed" then return end
	self:force_clear()
	self:set_state("failed")
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
	events.raise("cs2.delivery_state_changed", self, new_state, old_state)
end

function Delivery:is_in_final_state()
	return self.state == "completed" or self.state == "failed"
end

function Delivery:is_successfully_completed() return self.state == "completed" end

---Determine if this delivery is in a non-failed state between picking up items from the provider and delivery completion.
function Delivery:has_departed_provider() return false end

---Determine if this delivery is in a state where it is validly waiting for
---another world event (e.g. a queue slot to empty.)
function Delivery:is_in_wait_state() return false end

---Determine if a delivery should be considered stuck and alert or handle
---accordingly. Called by the monitor thread periodically.
---@param workload Core.Thread.Workload?
function Delivery:check_stuck(workload) end

---Determine if a delivery is cancellable by the user. This gates whether the "Cancel Delivery" button appears.
---@return boolean
function Delivery:is_cancellable()
	return self.state ~= "completed" and self.state ~= "failed"
end

---Clear virtual charge on `from` inventory.
function Delivery:clear_from_charge()
	if self.from_charge then
		local from_inv = cs2.get_inventory(self.from_inventory_id)
		if from_inv then from_inv:add_outflow_rebate(self.from_charge, -1) end
		self.from_charge = nil
	end
end

---Clear virtual charge on `to` inventory.
function Delivery:clear_to_charge()
	if self.to_charge then
		local to_inv = cs2.get_inventory(self.to_inventory_id)
		if to_inv then to_inv:add_inflow_rebate(self.to_charge, -1) end
		self.to_charge = nil
	end
end

---Clear all consequences of this delivery from queues, caches etc
function Delivery:force_clear()
	self:clear_to_charge()
	self:clear_from_charge()
	local from = cs2.get_node(self.from_id, true)
	if from then from:remove_delivery(self.id) end
	local to = cs2.get_node(self.to_id, true)
	if to then to:remove_delivery(self.id) end
	local veh = cs2.get_vehicle(self.vehicle_id)
	if veh then veh:fail_delivery(self.id) end
end

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
