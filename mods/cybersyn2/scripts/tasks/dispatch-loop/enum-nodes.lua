--------------------------------------------------------------------------------
-- enum_nodes
--
-- Compute full set of nodes in the topology.
--------------------------------------------------------------------------------

local strace = require("lib.core.strace")
local tlib = require("lib.core.table")
local cmt = require("lib.core.cmt")
local thread_lib = require("lib.core.thread")

local add_workload = thread_lib.add_workload

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

---@class (partial) Cybersyn.LogisticsThread
local LogisticsThread = cs2.LogisticsThread

function LogisticsThread:enum_nodes()
	-- TODO: PROFILING HOTSPOT (.700ms in large base)

	-- Use last count of nodes as workload estimate
	local last_n = self.n_total_nodes or 0
	if cmt.spike_yield(self, last_n) then return end

	-- Find all nodes in the topology
	local topology_id = self.topology_id
	local nodes, n_nodes, n_total_nodes = tlib.t_map_an(
		storage.nodes,
		function(node)
			if node:get_topology_id() == topology_id then return node end
		end
	)
	self.nodes = nodes
	self.n_nodes = n_nodes
	self.n_total_nodes = n_total_nodes
	add_workload(self.workload_counter, n_total_nodes)

	-- If no nodes, no work needs to be done, so sleep the thread and check
	-- again later.
	if n_nodes == 0 then
		self:set_state("init")
		self:clear_stats()
		cmt.sleep(self, 10 * 60) -- 10 sec
		cmt.yield(self)
		return
	end

	self:set_state("poll_nodes")
end
