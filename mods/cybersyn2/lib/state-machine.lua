if ... ~= "__cybersyn2__.lib.state-machine" then
	return require("__cybersyn2__.lib.state-machine")
end

local class = require("__cybersyn2__.lib.class").class

---@class StateMachine
local StateMachine = class()

---@param initial_state string
function StateMachine.new(initial_state)
	return setmetatable({ state = initial_state }, StateMachine)
end

---Change the current state of the state machine.
function StateMachine:set_state(new_state)
	if self.is_changing_state then
		if not self.queued_state_changes then
			self.queued_state_changes = { new_state }
		else
			table.insert(self.queued_state_changes, new_state)
		end
		return
	end

	local old_state = self.state
	if old_state == new_state then return end
	if not self:can_change_state(new_state, old_state) then return end

	self.is_changing_state = true
	self.state = new_state
	self:on_changed_state(new_state, old_state)
	self.is_changing_state = nil

	local queue = self.queued_state_changes
	if queue then
		self.queued_state_changes = nil
		for i = 1, #queue do
			self:set_state(queue[i])
		end
	end
end

---Determine if the state machine can change to the new state.
---Override in subclasses.
function StateMachine:can_change_state(new_state, old_state) return true end

---Fire events for when state changes. Override in subclasses.
function StateMachine:on_changed_state(new_state, old_state) end

return StateMachine
