if ... ~= "__cybersyn2__.lib.scheduler" then
	return require("__cybersyn2__.lib.scheduler")
end

local log = require("__cybersyn2__.lib.logging")
local counters = require("__cybersyn2__.lib.counters")

local lib = {}

---@alias Scheduler.Handler fun(task: Scheduler.Task)

---@alias Scheduler.TaskId integer

---@alias Scheduler.TaskSet {[Scheduler.TaskId]: true}

---@class Scheduler.Task
---@field id Scheduler.TaskId The unique identifier of the task
---@field type "once"|"many" The type of the task
---@field handler_name string The name of the callback handler
---@field data any Optional stateful data for the task. Note that this is stored in game state and must be serializable.

---@class Scheduler.OneOffTask: Scheduler.Task
---@field type "once" A one-off task
---@field at uint The tick at which the task should be executed

---@class Scheduler.RecurringTask: Scheduler.Task
---@field type "many" A recurring task
---@field period uint The number of ticks between executions
---@field next uint The next tick at which the task should be executed

---@class (exact) Scheduler.Storage
---@field tasks {[Scheduler.TaskId]: Scheduler.Task} The set of all tasks
---@field at {[uint]: Scheduler.TaskSet} The set of tasks scheduled for a given tick

---@type {[string]: Scheduler.Handler}
local handlers = {}

---Register a global handler callback for the scheduler. This should be done
---at the global level of the control phase unconditionally for each handler.
---@param name string
---@param handler Scheduler.Handler
function lib.register_handler(name, handler)
	handlers[name] = handler
end

---Initialize the scheduler system. Must be called in the mod's `on_init` handler.
function lib.init()
	if not storage._sched then
		storage._sched = {
			tasks = {},
			at = {},
		}
	end
end

local function do_at(tick, task_id)
	local state = storage._sched --[[@as Scheduler.Storage]]
	local task_set = state.at[tick]
	if not task_set then
		state.at[tick] = { [task_id] = true }
	else
		task_set[task_id] = true
	end
end

---Perform tasks for the given tick. MUST be called precisely once every tick by the `on_nth_tick(1)` handler.
---@param tick_data NthTickEventData
function lib.tick(tick_data)
	local state = storage._sched --[[@as Scheduler.Storage]]
	if not state then return end
	local tick_n = tick_data.tick
	local task_set = state.at[tick_n]
	if task_set then
		for task_id in pairs(task_set) do
			local task = state.tasks[task_id]
			if not task then goto continue end
			local handler = handlers[task.handler_name]
			if handler then
				handler(task)
			else
				log.once(log.level.error, "sched_handler_" .. task.handler_name, nil, nil, "Scheduler: missing handler",
					task.handler_name, "for task", task_id)
			end
			if task.type == "once" then
				state.tasks[task_id] = nil
			elseif task.type == "many" then
				local rtask = task --[[@as Scheduler.RecurringTask]]
				rtask.next = tick_n + rtask.period
				do_at(rtask.next, task_id)
			end
			::continue::
		end
		state.at[tick_n] = nil
	end
end

local function dont_at(tick, task_id)
	local state = storage._sched --[[@as Scheduler.Storage]]
	local task_set = state.at[tick]
	if task_set then task_set[task_id] = nil end
end

local function at(tick, handler_name, data)
	local state = storage._sched --[[@as Scheduler.Storage]]
	local task_id = counters.next("_task")
	local task = {
		id = task_id,
		type = "once",
		handler_name = handler_name,
		data = data,
		at = tick,
	}
	state.tasks[task_id] = task
	do_at(tick, task_id)
	log.trace("Scheduler: Created task", task)
	return task_id
end

local function every(first_tick, period, handler_name, data)
	local state = storage._sched --[[@as Scheduler.Storage]]
	local task_id = counters.next("_task")
	local task = {
		id = task_id,
		type = "many",
		handler_name = handler_name,
		data = data,
		period = period,
		next = first_tick,
	}
	state.tasks[task_id] = task
	do_at(first_tick, task_id)
	log.trace("Scheduler: Created task", task)
	return task_id
end

---Schedule a handler, previously registered with `register_handler`, to be
---executed at the given tick.
---@param tick uint The tick at which the handler should be executed
---@param handler_name string The name of the handler to execute
---@param data any Optional stateful data to be passed to the handler
---@return Scheduler.TaskId? #The unique identifier of the task, or `nil` if it couldnt be created.
function lib.at(tick, handler_name, data)
	if game and tick <= game.tick then
		log.debug("Scheduler: Attempted to schedule task in the past", tick, game.tick, handler_name)
		return nil
	end
	if not handlers[handler_name] then
		log.once(log.level.error, "sched_handler_" .. handler_name, nil, nil, "Scheduler: missing handler",
			handler_name)
		return nil
	end
	return at(tick, handler_name, data)
end

---Schedule a handler, previously registered with `register_handler`, to be
---executed in `ticks` ticks from now.
---@param ticks uint The number of ticks from now at which the handler should be executed
---@param handler_name string The name of the handler to execute
---@param data any Optional stateful data to be passed to the handler
---@return Scheduler.TaskId? #The unique identifier of the task, or `nil` if it couldnt be created.
function lib.after(ticks, handler_name, data)
	if ticks < 1 then
		log.debug("Scheduler: Attempted to schedule task in the past", ticks, handler_name)
		return nil
	end
	return lib.at(game.tick + ticks, handler_name, data)
end

---Schedule a handler, previously registered with `register_handler`, to be
---executed every `period` ticks.
---@param period uint The number of ticks between executions
---@param handler_name string The name of the handler to execute
---@param data any Optional stateful data to be passed to the handler
---@param skew uint? Optional skew to apply to the first execution. This can be used to disperse tasks with the same period from running all on the same tick.
---@return Scheduler.TaskId? #The unique identifier of the task, or `nil` if it couldnt be created.
function lib.every(period, handler_name, data, skew)
	if not handlers[handler_name] then
		log.once(log.level.error, "sched_handler_" .. handler_name, nil, nil, "Scheduler: missing handler",
			handler_name)
		return nil
	end
	local first_tick = game.tick + 1 + ((skew or 0) % period)
	return every(first_tick, period, handler_name, data)
end

---Get a task by ID if it exists.
---@param task_id Scheduler.TaskId
---@return Scheduler.Task? #The task, or `nil` if it doesn't exist.
function lib.get(task_id)
	local state = storage._sched --[[@as Scheduler.Storage]]
	if not state then return nil end
	return state.tasks[task_id]
end

---Change the period of an existing recurring task.
function lib.set_period(task_id, period)
	local task = lib.get(task_id) --[[@as Scheduler.RecurringTask]]
	if not task then return end
	task.period = period
end

return lib
