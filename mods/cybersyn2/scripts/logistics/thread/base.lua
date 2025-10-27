--------------------------------------------------------------------------------
-- Logistics thread
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local thread_lib = require("lib.core.thread")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

---@alias Cybersyn.LogisticsThreadState "init"|"enum_nodes"|"poll_nodes"|"alloc"|"route"

---@class (exact) Cybersyn.LogisticsThread: StatefulThread
---@field public state Cybersyn.LogisticsThreadState State of the task.
---@field public paused boolean? `true` if loop is paused
---@field public stepped boolean? `true` if user wants to execute one step
---@field public state_max_workload number Max workload for current state
---@field public topology_id Id Id of topology being serviced by this thread.
---@field public nodes Cybersyn.Node[]? Nodes found within topology.
---@field public providers? {[SignalKey]: Cybersyn.Order[]} Orders providing a given item.
---@field public requesters? {[SignalKey]: Cybersyn.Order[]} Orders requesting a given item.
---@field public request_all_items? Cybersyn.Order[] Orders requesting any item.
---@field public request_all_fluids? Cybersyn.Order[] Orders requesting any fluid.
---@field public allocations Cybersyn.Internal.LogisticsAllocation[]?
---@field public allocs_from {[Id]: Cybersyn.Internal.LogisticsAllocation[]} Allocations from the given stop, ordered. Used for multi-item.
---@field public avail_trains table<Id, Cybersyn.Train>? Available trains
local LogisticsThread = class("LogisticsThread", cs2.StatefulThread)
_G.cs2.LogisticsThread = LogisticsThread

---@param topology Cybersyn.Topology
function LogisticsThread:new(topology)
	local thread = cs2.StatefulThread.new(self) --[[@as Cybersyn.LogisticsThread]]
	thread.friendly_name = "logistics_" .. (topology.name or topology.id)
	thread.topology_id = topology.id
	thread.workload = 1
	thread:set_state("init")
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

function LogisticsThread:enter_init() self.nodes = nil end

function LogisticsThread:init()
	if mod_settings.enable_logistics then
		self:set_state("enum_nodes")
	else
		self:sleep_for(10 * 60) -- 10 sec
	end
end

-- Start threads when topologies are created/destroyed.
cs2.on_topologies(function(topology, action)
	if action == "created" then
		local thread = LogisticsThread:new(topology)
		topology.thread_id = thread.id
		thread:wake()
	elseif action == "destroyed" then
		local thread = thread_lib.get_thread(topology.thread_id)
		if thread then thread:kill() end
	end
end)

---@return Cybersyn.LogisticsThread?
function _G.cs2.debug.get_logistics_thread()
	-- TODO: this approach is entirely invalid, debugger now needs to enum
	-- topologies and retrieve threads from there.
	local tids = thread_lib.get_thread_ids()
	for _, id in pairs(tids) do
		local t = thread_lib.get_thread(id) --[[@as Cybersyn.LogisticsThread]]
		if t and t.topology_id == 1 then return t end
	end
end
