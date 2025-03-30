--------------------------------------------------------------------------------
-- poll_combinators phase
-- Read and cache all input info we will need for rest of logistics loop.
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local node_api = _G.cs2.node_api
local mod_settings = _G.cs2.mod_settings

---@param combinator_id UnitNumber
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_combinator(combinator_id, data)
	local combinator = combinator_api.get_combinator(combinator_id)
	if not combinator then
		log.trace("poll_combinator: skipping invalid comb", combinator_id)
		return
	end
	combinator_api.read_inputs(combinator)

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
