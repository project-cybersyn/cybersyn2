--------------------------------------------------------------------------------
-- Logistics thread
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local thread_lib = require("lib.core.thread")
local events = require("lib.core.event")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

local min = math.min
local max = math.max

local ALPHA = 1.0 / 20.0
local ONE_MINUS_ALPHA = 1 - ALPHA

---@alias Cybersyn.LogisticsThreadState "init"|"enum_nodes"|"poll_nodes"|"logistics"

---@class (exact) Cybersyn.LogisticsThread: StatefulThread
---@field public state Cybersyn.LogisticsThreadState State of the task.
---@field public topology_id Id Id of topology being serviced by this thread.
---@field public nodes Cybersyn.Node[]? Nodes found within topology.
---@field public providers? Cybersyn.Order[] Orders providing something
---@field public requesters? Cybersyn.Order[] Orders requesting something
---@field public trains? Cybersyn.Train[] Available trains
---@field public avail_trains? boolean[] Trains used this loop
local LogisticsThread = class("LogisticsThread", cs2.StatefulThread)
_G.cs2.LogisticsThread = LogisticsThread

---@param topology Cybersyn.Topology
function LogisticsThread:new(topology)
	local thread = cs2.StatefulThread.new(self) --[[@as Cybersyn.LogisticsThread]]
	thread.friendly_name = "logistics_" .. (topology.name or topology.id)
	thread.topology_id = topology.id
	thread.max_workload = cs2.PERF_BASE_LOGISTICS_WORKLOAD
		* cs2.mod_settings.work_factor
	thread.workload = 1
	thread:set_state("init")
	return thread
end

function LogisticsThread:enter_init() self.nodes = nil end

function LogisticsThread:init()
	if mod_settings.enable_logistics then
		self:set_state("enum_nodes")
		-- Resample workload to pick up changes in work factor.
		self.max_workload = cs2.PERF_BASE_LOGISTICS_WORKLOAD
			* cs2.mod_settings.work_factor
	else
		self:sleep_for(5 * 60) -- 5 sec
		self:yield()
	end
end

-- Start/stop threads when topologies are created/destroyed.
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
