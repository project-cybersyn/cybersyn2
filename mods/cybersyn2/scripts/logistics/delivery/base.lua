--------------------------------------------------------------------------------
-- Delivery abstraction
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local StateMachine = require("__cybersyn2__.lib.state-machine")
local counters = require("__cybersyn2__.lib.counters")
local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2

local strace = stlib.strace
local WARN = stlib.WARN

---@class Cybersyn.Delivery
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
function Delivery.get(id, skip_validation)
	if not id then return nil end
	local x = storage.deliveries[id]
	if skip_validation then
		return x
	elseif x then
		return x:is_valid() and x or nil
	end
end

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
