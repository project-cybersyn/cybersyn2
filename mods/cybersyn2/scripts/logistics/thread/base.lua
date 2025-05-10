--------------------------------------------------------------------------------
-- Logistics thread
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local thread_lib = require("__cybersyn2__.lib.thread")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

---@alias Cybersyn.LogisticsThreadState "init"|"poll_combinators"|"next_t"|"poll_nodes"|"alloc"|"route"

---@class Cybersyn.LogisticsThread: StatefulThread
---@field state Cybersyn.LogisticsThreadState State of the task.
---@field paused boolean? `true` if loop is paused
---@field stepped boolean? `true` if user wants to execute one step
---@field iteration int The current number of iterations in this state.
---@field topologies Cybersyn.Topology[]? Topologies to iterate
---@field current_topology int Current topology being iterated.
---@field combinators UnitNumber[]? Combinators to iterate
---@field active_topologies table<Id, true> Topologies seen while iterating combinators.
---@field nodes Cybersyn.Node[]? Nodes to iterate within topology.
---@field providers table<SignalKey, IdSet>? Idset of nodes providing the given product
---@field provided_qty SignalCounts? Total quantity of items provided by all providers
---@field providers_p table<SignalKey, [Cybersyn.Node, integer][][]>? p-grouped providers
---@field pushers table<SignalKey, IdSet>? Ids of nodes pushing the given product
---@field pushed_qty SignalCounts? Total quantity of items pushed by all pushers
---@field pushers_p table<SignalKey, [Cybersyn.Node, integer][][]>? p-grouped pushers
---@field pullers table<SignalKey, IdSet>? Ids of nodes pulling the given product
---@field pulled_qty SignalCounts? Total quantity of items pulled by all pullers
---@field pullers_p table<SignalKey, [Cybersyn.Node, integer][][]>? p-grouped pullers
---@field sinks table<SignalKey, IdSet>? Ids of nodes that are sinks for the given product
---@field sunk_qty SignalCounts? Total quantity of items sunk by all sinks
---@field sinks_p table<SignalKey, [Cybersyn.Node, integer][][]>? p-grouped sinks
---@field dumps Cybersyn.Node[]? Nodes that are dumps
---@field seen_cargo table<SignalKey, true>? Items we've seen and need to iterate over.
---@field allocations Cybersyn.Internal.LogisticsAllocation[]?
---@field cargo SignalKey[]? List of cargo.
---@field avail_trains table<Id, Cybersyn.Train>? Available trains
local LogisticsThread = class("LogisticsThread", cs2.StatefulThread)
_G.cs2.LogisticsThread = LogisticsThread

function LogisticsThread:new()
	local thread = cs2.StatefulThread.new(self) --[[@as Cybersyn.LogisticsThread]]
	thread.friendly_name = "logistics"
	thread.workload = 100
	thread:set_state("init")
	thread:wake()
	return thread
end

function LogisticsThread:main()
	if self.paused and not self.stepped then return end
	local state = self.state
	if not state then return end
	local handler = self[state]
	if not handler then return end
	handler(self)
	if self.stepped and self.paused then
		self.stepped = false
		cs2.raise_debug_loop("step", self)
	end
end

function LogisticsThread:enter_init()
	self.topologies = nil
	self.current_topology = nil
	self.active_topologies = nil
	self.nodes = nil
end

function LogisticsThread:init()
	if mod_settings.enable_logistics then self:set_state("poll_combinators") end
end

-- Start thread on startup.
cs2.on_startup(function() LogisticsThread:new() end)

---@return Cybersyn.LogisticsThread?
function _G.cs2.debug.get_logistics_thread()
	local tids = thread_lib.get_thread_ids()
	for _, id in pairs(tids) do
		local t = thread_lib.get_thread(id)
		if t and t.friendly_name == "logistics" then
			return t --[[@as Cybersyn.LogisticsThread]]
		end
	end
end
