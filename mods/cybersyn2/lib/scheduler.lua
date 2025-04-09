---@diagnostic disable: inject-field
if ... ~= "__cybersyn2__.lib.scheduler" then
	return require("__cybersyn2__.lib.scheduler")
end

local counters = require("__cybersyn2__.lib.counters")

local lib = {}

local strace = nil
local ERROR = 60
local WARN = 50
local TRACE = 10

---@alias Scheduler.Handler fun(task: Scheduler.Task): any

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

---Abort key that can be returned from schedule handlers to abort recurring
---tasks.
local ABORT = setmetatable({}, { __newindex = function() end })
lib.ABORT = ABORT

---Register a global handler callback for the scheduler. This should be done
---at the global level of the control phase unconditionally for each handler.
---@param name string
---@param handler Scheduler.Handler
function lib.register_handler(name, handler) handlers[name] = handler end

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
			if task then
				local handler = handlers[task.handler_name]
				local handler_result = nil
				if handler then
					handler_result = handler(task)
				else
					if strace then
						strace(
							ERROR,
							"scheduler",
							"missing_handler",
							"handler_name",
							task.handler_name
						)
					end
					handler_result = ABORT
				end
				-- Returning abort code can stop recurring tasks.
				if handler_result == ABORT then state.tasks[task_id] = nil end
				if task.type == "once" then
					state.tasks[task_id] = nil
				elseif task.type == "many" then
					local rtask = task --[[@as Scheduler.RecurringTask]]
					rtask.next = tick_n + rtask.period
					do_at(rtask.next, task_id)
				end
			end
		end
		state.at[tick_n] = nil
	end
end

local function dont_at(state, tick, task_id)
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
	if strace then strace(TRACE, "scheduler", "create_once", "task", task) end
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
	if strace then
		strace(TRACE, "scheduler", "create_recurring", "task", task)
	end
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
		if strace then
			strace(
				WARN,
				"scheduler",
				"past",
				"message",
				"attempted to schedule task in the past"
			)
		end
		return nil
	end
	if not handlers[handler_name] then
		if strace then
			strace(
				ERROR,
				"scheduler",
				"missing_handler",
				"handler_name",
				handler_name
			)
		end
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
		if strace then
			strace(
				WARN,
				"scheduler",
				"past",
				"message",
				"attempted to schedule task in the past"
			)
		end

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
		if strace then
			strace(
				ERROR,
				"scheduler",
				"missing_handler",
				"handler_name",
				handler_name
			)
		end
		return nil
	end
	local first_tick = game.tick + 1 + ((skew or 0) % period)
	return every(first_tick, period, handler_name, data)
end

---Get a task by ID if it exists.
---@param task_id Scheduler.TaskId
---@return Scheduler.Task? #The task, or `nil` if it doesn't exist.
local function get(task_id)
	local state = storage._sched --[[@as Scheduler.Storage]]
	if not state then return nil end
	return state.tasks[task_id]
end
lib.get = get

---Change the period of an existing recurring task.
function lib.set_period(task_id, period)
	local task = lib.get(task_id) --[[@as Scheduler.RecurringTask]]
	if not task then return end
	task.period = period
end

---Stop a task
---@return boolean `true` if a task record was deleted
function lib.stop(task_id)
	local state = storage._sched --[[@as Scheduler.Storage]]
	local task = state.tasks[task_id] --[[@as Scheduler.RecurringTask]]
	if not task then return false end
	state.tasks[task_id] = nil
	return true
end

---Set strace handler. `nil` disables tracing entirely.
---@param handler? fun(level: int, ...)
function lib.set_strace_handler(handler) strace = handler end

return lib
