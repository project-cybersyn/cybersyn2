--------------------------------------------------------------------------------
-- next_t phase
-- Iterate to the next topology in the enumerated list, or reset the
-- mainloop if we run out of topologies.
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

--------------------------------------------------------------------------------
-- Loop state lifecycle
--------------------------------------------------------------------------------

---@param data Cybersyn.Internal.LogisticsThreadData
local function cleanup_next_t(data)
	data.topologies = nil
	data.current_topology = nil
	data.active_topologies = nil
	data.nodes = nil
	cs2.logistics_thread.goto_init(data)
end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.goto_next_t(data)
	if not data.topologies then
		if data.active_topologies then
			data.topologies = tlib.t_map_a(
				data.active_topologies,
				function(_, k) return cs2.node_api.get_topology(k) end
			)
			data.current_topology = 1
		else
			log.warn("logistics_thread.goto_next_t: invalid state")
			return cleanup_next_t(data)
		end
	else
		data.current_topology = data.current_topology + 1
	end
	cs2.logistics_thread.set_state(data, "next_t")
end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.next_t(data)
	local topology = data.topologies[data.current_topology]
	if not topology then return cleanup_next_t(data) end
	local id = topology.id
	data.nodes = tlib.t_map_a(storage.nodes, function(node)
		if node.topology_id == id then return node end
	end)
	_G.cs2.logistics_thread.goto_poll_nodes(data)
end
