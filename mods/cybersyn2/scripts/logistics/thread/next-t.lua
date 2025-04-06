--------------------------------------------------------------------------------
-- next_t phase
-- Iterate to the next topology in the enumerated list, or reset the
-- mainloop if we run out of topologies.
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings
local inventory_api = _G.cs2.inventory_api
local Topology = _G.cs2.Topology

--------------------------------------------------------------------------------
-- Loop state lifecycle
--------------------------------------------------------------------------------

---@param data Cybersyn.Internal.LogisticsThreadData
local function cleanup_next_t(data)
	data.topologies = nil
	data.current_topology = nil
	data.active_topologies = nil
	data.nodes = nil
	-- XXX: temp debugging
	-- clear allocations (dispatch phase should do this)
	if data.allocations then
		for _, alloc in pairs(data.allocations) do
			inventory_api.add_flow(alloc.from_inv, { [alloc.item] = alloc.qty }, 1)
			inventory_api.add_flow(alloc.to_inv, { [alloc.item] = alloc.qty }, -1)
		end
		data.allocations = nil
	end
	cs2.logistics_thread.goto_init(data)
end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.goto_next_t(data)
	if not data.topologies then
		if data.active_topologies then
			data.topologies = tlib.t_map_a(
				data.active_topologies,
				function(_, k) return Topology.get(k) end
			)
			data.current_topology = 1
		else
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
