--------------------------------------------------------------------------------
-- enum_nodes
--
-- Compute full set of nodes and associated combinators in the topology.
--------------------------------------------------------------------------------

local stlib = require("lib.core.strace")
local tlib = require("lib.core.table")
local thread_lib = require("lib.core.thread")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

local Node = _G.cs2.Node
local Combinator = _G.cs2.Combinator
local strace = stlib.strace
local DEBUG = stlib.DEBUG
local TRACE = stlib.TRACE
local empty = tlib.empty
local add_workload = thread_lib.add_workload
local table_size = _G.table_size

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

function LogisticsThread:enter_enum_nodes()
	-- Find all nodes in the topology
	local topology_id = self.topology_id
	local nodes = tlib.t_map_a(storage.nodes, function(node)
		if node.topology_id == topology_id then return node end
	end)
	self.nodes = nodes
	local n_nodes = #nodes
	add_workload(self.workload_counter, table_size(storage.nodes))

	-- If no nodes, no work needs to be done, so sleep the thread and check
	-- again later.
	if n_nodes == 0 then
		self:set_state("init")
		self.workload = 1
		self.ema_workload = 1
		self.workload_counter.workload = 1
		self:sleep_for(10 * 60) -- 10 sec
		self:yield()
		return
	end
end

function LogisticsThread:enum_nodes() self:set_state("poll_nodes") end
