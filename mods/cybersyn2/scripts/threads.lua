--------------------------------------------------------------------------------
-- Thread scheduling helper
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local StateMachine = require("lib.core.state-machine")
local scheduler = require("lib.core.scheduler")
local thread = require("lib.core.thread")
local events = require("lib.core.event")
local strace = require("lib.core.strace")

local Thread = thread.Thread
local cs2 = _G.cs2

local max = math.max
local min = math.min
local ALPHA = 1.0 / 20.0
local ONE_MINUS_ALPHA = 1 - ALPHA
local add_workload = thread.add_workload

-- TODO: copy work period startup setting into thread global storage.

---@class StatefulThread: Core.Thread, StateMachine
---@field public stride? int For enumerating threads, the number of elements to loop over in a single iteration
---@field public index? any The current index in the async iteration, if applicable
---@field public iterable? any[]|table The array or table being async iterated over, if applicable
---@field public workload_counter Core.Thread.Workload Current workload.
---@field public ema_workload number Exponential moving average of workload.
---@field public max_workload number Target max workload.
---@field public paused boolean? `true` if loop is paused
---@field public stepped boolean? `true` if user wants to execute one step
local StatefulThread = class("StatefulThread", Thread, StateMachine)
_G.cs2.StatefulThread = StatefulThread

---@param initial_state string
function StatefulThread:new(initial_state)
	local thr = Thread.new(self) --[[@as StatefulThread]]
	thr.state = initial_state
	thr.max_workload =
		math.ceil(cs2.PERF_BASE_THREAD_WORKLOAD * cs2.mod_settings.work_factor)
	thr.workload = 1
	thr.ema_workload = 0
	thr.workload_counter = { workload = 0 }
	return thr
end

function StatefulThread:main()
	if self.paused then
		if not self.stepped then return end
		strace.trace("Stepping paused thread:", self.id, self.friendly_name)
	end
	local total_workload
	local loops = 0
	while true do
		local state = self.state
		if not state then
			self.workload_counter.workload = 0
			return
		end
		local handler = self[state]
		if not handler then
			self.workload_counter.workload = 0
			return
		end
		handler(self)
		total_workload = add_workload(self.workload_counter, 1)
		-- Always break when paused to allow granular stepping in the debugger
		if self.paused or (total_workload >= self.max_workload) then break end
		loops = loops + 1
		if loops >= 10000 then
			strace.trace(
				"Thread",
				self.id,
				self.friendly_name,
				"exceeded max loop iterations without yielding in state",
				self.state
			)
			break
		end
	end
	self.ema_workload = (ONE_MINUS_ALPHA * self.ema_workload)
		+ (ALPHA * total_workload)
	self.workload = max(self.ema_workload, 1)
	if self.stepped and self.paused then
		self.stepped = false
		events.raise("cs2.debug_thread_step", self)
	end
	self.workload_counter.workload = 0
end

---Initializes thread state to asynchronously iterate over an array.
---@param array any[] The array to loop over.
---@param stride? int The number of elements to loop over in a single iteration. Defaults to 1.
function StatefulThread:begin_async_loop(array, stride)
	-- Initialize the thread state for async iteration
	self.stride = stride or 1
	self.index = 1
	self.iterable = array
end

---@param t table The table to loop over.
---@param stride? int The number of elements to loop over in a single iteration. Defaults to 1.
function StatefulThread:begin_async_pairs(t, stride)
	-- Initialize the thread state for async iteration over a table
	self.stride = stride or 1
	self.index = nil
	self.iterable = t
end

---Perform an asynchronous loop over an array, calling `step(self, element)`
---for each element in groups of `self.stride` per iteration.
---Calls `finish(self)` when the loop is complete.
---@param step fun(self: StatefulThread, element: any, index?: int, array?: any[])
---@param finish fun(self: StatefulThread)
function StatefulThread:step_async_loop(step, finish)
	local array = self.iterable
	if not array then return finish(self) end
	local max_index = min(self.index + max(self.stride, 1) - 1, #array)
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

---@param step fun(self: StatefulThread, v: any, k: any, T?: table)
---@param finish fun(self: StatefulThread)
function StatefulThread:step_async_pairs(step, finish)
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
