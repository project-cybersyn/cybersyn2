--------------------------------------------------------------------------------
-- poll_combinators phase
--
-- Read and cache all input signals from input-mode combinators in the topology.
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
	self:begin_async_loop(
		self.combinators,
		math.ceil(cs2.PERF_POLL_COMBINATORS_WORKLOAD * mod_settings.work_factor)
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
end

function LogisticsThread:poll_combinators()
	self:step_async_loop(
		self.poll_combinator,
		function(thr) thr:set_state("poll_nodes") end
	)
end
