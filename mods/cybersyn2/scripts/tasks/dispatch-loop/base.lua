--------------------------------------------------------------------------------
-- Logistics thread
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local cmt = require("lib.core.cmt")
local events = require("lib.core.event")
local strace = require("lib.core.strace")
local cs2 = _G.cs2
local mod_settings = cs2.mod_settings

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

---@alias Cybersyn.LogisticsThreadState "init"|"enum_nodes"|"poll_nodes"|"logistics"

---@class (partial) Cybersyn.LogisticsThread: StatefulTask
---@field public state Cybersyn.LogisticsThreadState State of the task.
---@field public topology_id Id Id of topology being serviced by this thread.
---@field public nodes Cybersyn.Node[] Nodes found within topology.
---@field public providers Cybersyn.Order[] Orders providing something
---@field public requesters Cybersyn.Order[] Orders requesting something
---@field public trains Cybersyn.Train[] Available trains
---@field public avail_trains boolean[] Availability of each train in `trains`
local LogisticsThread = class("LogisticsThread", cs2.StatefulTask)
cs2.LogisticsThread = LogisticsThread

---@param topology Cybersyn.Topology
function LogisticsThread:new(topology)
	-- Kill existing thread if the topo has one
	local existing_thread = cmt.get(topology.thread_id)
	if existing_thread then
		strace.warn(
			"Killing existing logistics thread",
			existing_thread._cmt_id,
			"for topology",
			topology.name
		)
		cmt.kill(existing_thread)
	end

	local thread = cs2.StatefulTask.new(self) --[[@as Cybersyn.LogisticsThread]]
	thread.state = "init"
	thread._cmt_name = "logistics_" .. (topology.name or topology.id)
	thread.topology_id = topology.id
	thread._cmt_work_cap = 100
	cmt.add(thread)
	cmt.wake(thread)
	topology.thread_id = thread._cmt_id
	strace.warn(
		"Created logistics thread",
		thread._cmt_id,
		"for topology",
		topology.name
	)
	return thread
end

function LogisticsThread:enter_init() self.nodes = nil end

function LogisticsThread:init()
	if mod_settings.enable_logistics then
		events.raise("cs2.logistics_loop_start", self, self.topology_id)
		self:set_state("enum_nodes")
		-- Resample workload to pick up changes in work factor.
		self._cmt_work_cap = cs2.PERF_BASE_LOGISTICS_WORKLOAD
			* cs2.mod_settings.work_factor
	else
		cmt.sleep(self, 5 * 60) -- 5 sec
		cmt.yield(self)
	end
end

--------------------------------------------------------------------------------
-- Thread startup
--------------------------------------------------------------------------------

events.bind(
	"cs2.topology_created",
	function(topology) LogisticsThread:new(topology) end
)

events.bind("cs2.topology_destroyed", function(topology)
	local thread = cmt.get(topology.thread_id)
	if thread then cmt.kill(thread) end
	topology.thread_id = nil
end)

events.bind("cs2.threads_start_all", function()
	for _, topology in pairs(storage.topologies) do
		if not cmt.get(topology.thread_id) then LogisticsThread:new(topology) end
	end
end)
