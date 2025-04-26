--------------------------------------------------------------------------------
-- Thread scheduling helper
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local StateMachine = require("__cybersyn2__.lib.state-machine")
local scheduler = require("__cybersyn2__.lib.scheduler")
local cs2 = _G.cs2

local max = math.max
local min = math.min

---@class Thread
local Thread = class()
_G.cs2.Thread = Thread

---Main loop of the thread. Override in child classes.
function Thread:main() end

scheduler.register_handler("thread_handler", function(task)
	(task.data --[[@as Thread]]):main()
end)

---Schedule a thread to run every `work_period` ticks, automatically updating
---when user changes mod settings.
---@param name string
---@param offset int Tick offset for task. Should be set differently than other tasks in the mod so all threads don't update on the same tick.
---@param constructor fun(): Thread Construct initial thread if it doesn't exist.
function _G.cs2.schedule_thread(name, offset, constructor)
	cs2.on_mod_settings_changed(function()
		if storage.task_ids[name] then
			scheduler.set_period(storage.task_ids[name], cs2.mod_settings.work_period)
		else
			storage.task_ids[name] = scheduler.every(
				cs2.mod_settings.work_period,
				"thread_handler",
				constructor(),
				offset
			)
		end
	end)
end

---@class StatefulThread: Thread, StateMachine
---@field public stride int? For enumerating threads, the number of elements to loop over in a single iteration
---@field public index int? The current index in the enumeration, if applicable
local StatefulThread = class(nil, Thread, StateMachine)
_G.cs2.StatefulThread = StatefulThread

function StatefulThread:main()
	local state = self.state
	if not state then return end
	local handler = self[state]
	if not handler then return end
	handler(self)
end

---Perform an asynchronous loop over an array, calling `step(self, element)`
---for each element in groups of `self.stride` per iteration.
---Calls `finish(self)` when the loop is complete.
---@param array any[] The array to loop over. (MUST be stable across iterations; best to copy and store in thread state if in doubt.)
---@param step fun(self: StatefulThread, element: any, index?: int, array?: any)
---@param finish fun(self: StatefulThread)
function StatefulThread:async_loop(array, step, finish)
	local max_index = min(self.index + max(self.stride, 1) - 1, #array)
	for i = self.index, max_index do
		step(self, array[i], i, array)
	end
	if max_index >= #array then
		finish(self)
	else
		self.index = max_index + 1
	end
end
