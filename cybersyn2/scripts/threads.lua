--------------------------------------------------------------------------------
-- Thread scheduling helper
--------------------------------------------------------------------------------

local scheduler = require("__cybersyn2__.lib.scheduler")
local log = require("__cybersyn2__.lib.logging")

threads_api = {}

---Schedule a thread to run every `work_period` ticks, automatically updating
---when user changes mod settings. The thread begins with `{ state = "init" }`
---as its initial data.
---@param name string
---@param main fun(state: Scheduler.RecurringTask)
---@param offset int Tick offset for task. Should be set differently than other tasks in the mod so all threads don't update on the same tick.
function threads_api.schedule_thread(name, main, offset)
	scheduler.register_handler(name, main)

	on_mod_settings_changed(function()
		if storage.task_ids[name] then
			scheduler.set_period(storage.task_ids[name], mod_settings.work_period)
		else
			storage.task_ids[name] = scheduler.every(
				mod_settings.work_period,
				name,
				{
					state = "init",
				},
				offset
			)
		end
	end)
end

---Generate a standard main loop closure for a thread which executes
---functions from `dispatch_table` based on the current `state` field of the
---thread's data.
---@param dispatch_table table<string, fun(data: table)>
function threads_api.create_standard_main_loop(dispatch_table)
	return function(task)
		local data = task.data
		local state = data.state
		if not state then
			log.error("Invalid thread state:", state)
			return
		end

		local func = dispatch_table[state]
		if not func then
			log.error("Invalid thread state:", state)
			return
		end

		func(data)
	end
end
