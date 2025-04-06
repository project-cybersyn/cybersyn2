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

function Delivery:destroy()
	local id = self.id
	local delivery = storage.deliveries[id]
	if not delivery then return end
	cs2.raise_delivery_destroyed(delivery)
	storage.deliveries[id] = nil
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
	cs2.raise_delivery_state_changed(self, new_state, old_state)
end
