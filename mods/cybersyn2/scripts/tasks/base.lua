local class = require("lib.core.class").class
local cmt = require("lib.core.cmt")
local StateMachine = require("lib.core.state-machine")

local next = next
local min = math.min

local lib = {}

---@class StatefulTask: Core.CMT.Task, StateMachine
---@field public stride? int For enumerating threads, the number of elements to loop over in a single iteration
---@field public index? any The current index in the async iteration, if applicable
---@field public iterable? any[]|table The array or table being async iterated over, if applicable
---@field public workload_counter Core.Thread.Workload Current workload.
local StatefulTask = class("StatefulTask", cmt.Task, StateMachine)
cs2.StatefulTask = StatefulTask

function StatefulTask:main()
	local state = self.state
	if not state then return 0 end
	local handler = self[state]
	if not handler then return 0 end
	local wc = self.workload_counter
	wc.workload = 0
	handler(self)
	return wc.workload
end

---Initializes task state to asynchronously iterate over an array.
---@param array any[] The array to loop over.
---@param stride? int The number of elements to loop over in a single iteration. Defaults to 1.
function StatefulTask:begin_async_loop(array, stride)
	-- Initialize the task state for async iteration
	self.stride = stride or 1
	self.index = 1
	self.iterable = array
end

---@param t table The table to loop over.
---@param stride? int The number of elements to loop over in a single iteration. Defaults to 1.
function StatefulTask:begin_async_pairs(t, stride)
	-- Initialize the task state for async iteration over a table
	self.stride = stride or 1
	self.index = nil
	self.iterable = t
end

---Perform an asynchronous loop over an array, calling `step(self, element)`
---for each element in groups of `self.stride` per iteration.
---Calls `finish(self)` when the loop is complete.
---@param step fun(self: StatefulTask, element: any, index?: int, array?: any[])
---@param finish fun(self: StatefulTask)
function StatefulTask:step_async_loop(step, finish)
	local array = self.iterable
	local stride = self.stride or 1
	if not array then return finish(self) end
	local max_index = min(self.index + stride - 1, #array)
	for i = self.index, max_index do
		step(self, array[i], i, array)
	end
	if max_index >= #array then
		self.iterable = nil
		finish(self)
	else
		self.index = max_index + 1
	end
end

---@param step fun(self: StatefulTask, v: any, k: any, T?: table)
---@param finish fun(self: StatefulTask)
function StatefulTask:step_async_pairs(step, finish)
	local T = self.iterable
	if not T then return finish(self) end
	local index = self.index
	local finished = false
	for i = 1, self.stride do
		local v
		index, v = next(T, index)
		if index == nil then
			finished = true
			break
		end
		step(self, v, index, T)
	end
	if finished then
		self.iterable = nil
		finish(self)
	else
		self.index = index
	end
end

--------------------------------------------------------------------------------
-- Workload utilities
--------------------------------------------------------------------------------

---Utility function for adding to a workload object.
---@param workload Core.Thread.Workload|nil
---@param qty number
---@return number total_workload New workload total, or `qty` if `workload` is `nil`.
function lib.add_workload(workload, qty)
	-- Check for NAN
	if (not qty) or (qty ~= qty) then
		if workload then
			return workload.workload
		else
			return 0
		end
	end

	if workload then
		local x = workload.workload
		local x1 = x + qty
		workload.workload = x1
		return x1
	else
		return qty
	end
end

---Utility function for getting workload value from a workload object.
---@param workload Core.Thread.Workload | nil
---@return number workload
function lib.get_workload(workload) return workload and workload.workload or 0 end

return lib
