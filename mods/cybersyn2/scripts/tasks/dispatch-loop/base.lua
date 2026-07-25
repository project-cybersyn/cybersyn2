--------------------------------------------------------------------------------
-- Logistics thread
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local cmt = require("lib.core.cmt")
local events = require("lib.core.event")
local strace = require("lib.core.strace")
local era_lib = require("lib.core.math.era-counter")
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
---@field public n_nodes integer Number of nodes in topology
---@field public requesters_era Core.EraCounter Era of number of unsatisfied requesters
---@field public n_providers integer Initial number of providers.
---@field public last_loop_tick? int64 Last loop completion tick
---@field public loop_length_era Core.EraCounter Era of loop length
---@field public last_poll_nodes_tick? int64 Last tick the thread polled nodes
---@field public poll_nodes_era Core.EraCounter Era of node polling time
---@field public last_logistics_tick? int64 Last tick the thread completed logistics
---@field public logistics_era Core.EraCounter Era of logistics time
---@field public n_deliveries integer Number of deliveries made in last loop
---@field public deliveries_era Core.EraCounter Era of number of deliveries
---@field public deliveries_frame_era Core.EraCounter Era of number of deliveries per frame.
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
	thread._cmt_spike_cap = 50
	thread.n_nodes = 0
	thread.n_avail_trains = 0
	thread.n_providers = 0
	thread.requesters_era = era_lib.create_era_counter(0)
	thread.loop_length_era = era_lib.create_era_counter(0)
	thread.poll_nodes_era = era_lib.create_era_counter(0)
	thread.logistics_era = era_lib.create_era_counter(0)
	thread.deliveries_era = era_lib.create_era_counter(0)
	thread.deliveries_frame_era = era_lib.create_era_counter(0, 0.1)
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

function LogisticsThread:clear_stats()
	self.n_nodes = 0
	self.n_avail_trains = 0
	self.n_providers = 0
	self.n_deliveries = 0
	self.last_loop_tick = nil
	local era = self.loop_length_era
	if not era then self.loop_length_era = era_lib.create_era_counter(0) end
end

function LogisticsThread:mark_loop_start()
	local t = game.tick
	local t0 = self.last_loop_tick
	if t0 then
		local dt = t - t0
		era_lib.create_or_update_era_counter(self, "loop_length_era", dt)
		if dt > 0 then
			era_lib.create_or_update_era_counter(
				self,
				"deliveries_frame_era",
				(self.n_deliveries or 0) / dt,
				0.1
			)
		end
	end
	self.last_loop_tick = t
	events.raise("cs2.logistics_loop_start", self, self.topology_id)
end

function LogisticsThread:enter_init() self.nodes = nil end

function LogisticsThread:init()
	if game and mod_settings.enable_logistics then
		self:mark_loop_start()
		self:set_state("enum_nodes")
	else
		self:clear_stats()
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
