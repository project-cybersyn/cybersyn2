--------------------------------------------------------------------------------
-- enum_nodes
--
-- Compute full set of nodes and associated combinators in the topology.
--------------------------------------------------------------------------------

local stlib = require("__cybersyn2__.lib.strace")
local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

local Node = _G.cs2.Node
local Combinator = _G.cs2.Combinator
local strace = stlib.strace
local DEBUG = stlib.DEBUG
local TRACE = stlib.TRACE
local empty = tlib.empty

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

	-- If no nodes, no work needs to be done, so sleep the thread and check
	-- again later.
	if n_nodes == 0 then
		self:set_state("init")
		self.workload = 1
		self:sleep_for(2 * 60 * 60) -- 2 minutes
		return
	end

	self.combinators = {}
	-- TODO: better workload calc
	self.workload = n_nodes * 10
	self:begin_async_loop(
		self.nodes,
		math.ceil(cs2.PERF_ENUM_NODES_WORKLOAD * mod_settings.work_factor)
	)
end

---@param node Cybersyn.Node
function LogisticsThread:enum_node(node)
	local combinators = self.combinators
	for id in pairs(node.combinator_set or empty) do
		combinators[#combinators + 1] = id
	end
end

function LogisticsThread:enum_nodes()
	self:step_async_loop(
		self.enum_node,
		function(thr) thr:set_state("poll_combinators") end
	)
end
