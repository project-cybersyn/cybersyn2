--------------------------------------------------------------------------------
-- Logistics thread
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local scheduler = require("__cybersyn2__.lib.scheduler")
local cs2 = _G.cs2
local threads_api = _G.cs2.threads_api

_G.cs2.logistics_thread = {}
local dispatch_table = _G.cs2.logistics_thread

---@alias Cybersyn.Internal.LogisticsThreadState "init"|"poll_combinators"|"next_t"|"poll_nodes"

---@class (exact) Cybersyn.Internal.LogisticsThreadData
---@field state Cybersyn.Internal.LogisticsThreadState State of the task.
---@field paused boolean? `true` if loop is paused
---@field stepped boolean? `true` if user wants to execute one step
---@field iteration int The current number of iterations in this state.
---@field stride int The number of items to process per iteration
---@field index int The current index in the enumeration.
---@field topologies Cybersyn.Topology[]? Topologies to iterate
---@field current_topology int Current topology being iterated.
---@field combinators UnitNumber[]? Combinators to iterate
---@field active_topologies table<Id, true> Topologies seen while iterating combinators.
---@field nodes Cybersyn.Node[]? Nodes to iterate within topology.
---@field providers table<SignalKey, Cybersyn.Node[]>? Ids of nodes providing the given product
---@field pushers table<SignalKey, Cybersyn.Node[]>? Ids of nodes pushing the given product
---@field pullers table<SignalKey, Cybersyn.Node[]>? Ids of nodes pulling the given product
---@field sinks table<SignalKey, Cybersyn.Node[]>? Ids of nodes that are sinks for the given product
---@field dumps Cybersyn.Node[]? Nodes that are dumps
---@field seen_cargo table<SignalKey, true>? Items we've seen and need to iterate over.

---@class Cybersyn.Internal.LogisticsThread: Scheduler.RecurringTask
---@field public data Cybersyn.Internal.LogisticsThreadData

---@param task Cybersyn.Internal.LogisticsThread
local function main_loop(task)
	local data = task.data
	-- TODO: pause/resume/step
	if data.paused and not data.stepped then return end
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
	data.stepped = false
	if data.paused then cs2.raise_debug_loop("step", data) end
end

-- TODO: logistics start pauised for debugging, change for beta.
threads_api.schedule_thread(
	"logistics",
	main_loop,
	0,
	{ state = "init", paused = true }
)

---@param data Cybersyn.Internal.LogisticsThreadData
---@param state Cybersyn.Internal.LogisticsThreadState
function _G.cs2.logistics_thread.set_state(data, state)
	if state ~= data.state then
		data.state = state
		cs2.raise_debug_loop("state", data)
	end
end

function _G.cs2.logistics_thread.goto_init(data)
	cs2.logistics_thread.set_state(data, "init")
end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.init(data)
	_G.cs2.logistics_thread.goto_poll_combinators(data)
end

---@return Cybersyn.Internal.LogisticsThreadData?
function _G.cs2.debug.get_logistics_thread_data()
	local id = storage.task_ids["logistics"]
	if id then
		local t = scheduler.get(id) --[[@as Cybersyn.Internal.LogisticsThread]]
		if t then return t.data end
	end
end

--------------------------------------------------------------------------------
-- Helper fns
--------------------------------------------------------------------------------

---Execute `stride` iterations of a general loop over state data.
---@param data Cybersyn.Internal.LogisticsThreadData
---@param list any[]
---@param item_handler fun(item: any, data: Cybersyn.Internal.LogisticsThreadData)
---@param finish_handler fun(data: Cybersyn.Internal.LogisticsThreadData)
function _G.cs2.logistics_thread.stride_loop(
	data,
	list,
	item_handler,
	finish_handler
)
	local n = #list
	-- Handle `stride` number of items
	local max_index = math.min(data.index + data.stride, n)
	for i = data.index, max_index do
		item_handler(list[i], data)
	end
	-- If this finished, exec the finish handler
	if max_index >= n then
		finish_handler(data)
	else
		data.index = max_index + 1
	end
end
