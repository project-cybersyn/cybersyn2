--------------------------------------------------------------------------------
-- poll_combinators phase
-- Read and cache all input info we will need for rest of logistics loop.
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

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

function LogisticsThread:enter_poll_combinators()
	self.active_topologies = {}
	self:begin_async_loop(
		tlib.t_map_a(storage.combinators, function(_, k) return k end),
		math.ceil(cs2.PERF_COMB_POLL_WORKLOAD * mod_settings.work_factor)
	)
end

---@param combinator_id UnitNumber
function LogisticsThread:poll_combinator(combinator_id)
	local combinator = Combinator.get(combinator_id)
	if not combinator then
		strace(
			TRACE,
			"message",
			"poll_combinator: skipping invalid comb",
			combinator_id
		)
		return
	end
	combinator:read_inputs()

	-- Mark a topology as active if the owning node of a combinator is in that
	-- topology.
	local node = Node.get(combinator.node_id)
	if node and node.topology_id then
		self.active_topologies[node.topology_id] = true
	end
end

function LogisticsThread:poll_combinators()
	self:step_async_loop(
		self.poll_combinator,
		function(thr) thr:set_state("next_t") end
	)
end
