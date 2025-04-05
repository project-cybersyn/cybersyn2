--------------------------------------------------------------------------------
-- poll_combinators phase
-- Read and cache all input info we will need for rest of logistics loop.
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local stlib = require("__cybersyn2__.lib.strace")
local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local node_api = _G.cs2.node_api
local mod_settings = _G.cs2.mod_settings

local Combinator = _G.cs2.Combinator
local strace = stlib.strace
local DEBUG = stlib.DEBUG
local TRACE = stlib.TRACE

---@param combinator_id UnitNumber
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_combinator(combinator_id, data)
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
	strace(
		DEBUG,
		"poll_combinators",
		combinator_id,
		"message",
		"read inputs:",
		combinator.inputs
	)

	-- Mark a topology as active if the owning node of a combinator is in that
	-- topology.
	local node = node_api.get_node(combinator.node_id)
	if node and node.topology_id then
		data.active_topologies[node.topology_id] = true
	end
end

--------------------------------------------------------------------------------
-- Loop state lifecycle
--------------------------------------------------------------------------------

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.goto_poll_combinators(data)
	data.active_topologies = {}
	data.combinators = tlib.t_map_a(
		storage.combinators,
		function(_, k) return k end
	)
	data.stride =
		math.ceil(mod_settings.work_factor * cs2.PERF_COMB_POLL_WORKLOAD)
	data.index = 1
	data.iteration = 1
	cs2.logistics_thread.set_state(data, "poll_combinators")
end

---@param data Cybersyn.Internal.LogisticsThreadData
local function cleanup_poll_combinators(data)
	cs2.logistics_thread.goto_next_t(data)
end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.poll_combinators(data)
	cs2.logistics_thread.stride_loop(
		data,
		data.combinators,
		poll_combinator,
		function(data2) cleanup_poll_combinators(data2) end
	)
end
