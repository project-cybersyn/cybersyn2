--------------------------------------------------------------------------------
-- Thread scheduling helper
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local StateMachine = require("__cybersyn2__.lib.state-machine")
local scheduler = require("__cybersyn2__.lib.scheduler")
local thread = require("__cybersyn2__.lib.thread")
local Thread = thread.Thread
local cs2 = _G.cs2

local max = math.max
local min = math.min

-- TODO: copy work period startup setting into thread global storage.

-- Legacy handler: bind old threads to noop so alpha saves don't crash.
-- TODO: remove at release
scheduler.register_handler("thread_handler", function() end)

---@class StatefulThread: Lib.Thread, StateMachine
---@field public stride? int For enumerating threads, the number of elements to loop over in a single iteration
---@field public index? int The current index in the enumeration, if applicable
---@field public iterating? any[] The array being iterated over, if applicable
local StatefulThread = class("StatefulThread", Thread, StateMachine)
_G.cs2.StatefulThread = StatefulThread

---@param initial_state? string
function StatefulThread:new(initial_state)
	local thr = Thread.new(self) --[[@as StatefulThread]]
	thr.state = initial_state
	return thr
end

function StatefulThread:main()
	local state = self.state
	if not state then return end
	local handler = self[state]
	if not handler then return end
	handler(self)
end

---Initializes thread state to asynchronously iterate over an array.
---@param array any[] The array to loop over.
---@param stride? int The number of elements to loop over in a single iteration. Defaults to 1.
function StatefulThread:begin_async_loop(array, stride)
	-- Initialize the thread state for async iteration
	self.stride = stride or 1
	self.index = 1
	self.iterating = array
end

---Perform an asynchronous loop over an array, calling `step(self, element)`
---for each element in groups of `self.stride` per iteration.
---Calls `finish(self)` when the loop is complete.
---@param step fun(self: StatefulThread, element: any, index?: int, array?: any)
---@param finish fun(self: StatefulThread)
function StatefulThread:step_async_loop(step, finish)
	local array = self.iterating
	if not array then return finish(self) end
	local max_index = min(self.index + max(self.stride, 1) - 1, #array)
	for i = self.index, max_index do
		step(self, array[i], i, array)
	end
	if max_index >= #array then
		self.iterating = nil
		finish(self)
	else
		self.index = max_index + 1
	end
end
