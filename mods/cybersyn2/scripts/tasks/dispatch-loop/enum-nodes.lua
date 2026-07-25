--------------------------------------------------------------------------------
-- enum_nodes
--
-- Compute full set of nodes and associated combinators in the topology.
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

function LogisticsThread:enter_enum_nodes()
	-- TODO: PROFILING HOTSPOT (.700ms in large base)

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
end

function LogisticsThread:enum_nodes() self:set_state("poll_nodes") end
