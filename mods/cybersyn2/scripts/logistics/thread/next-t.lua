--------------------------------------------------------------------------------
-- next_t phase
-- Iterate to the next topology in the enumerated list, or reset the
-- mainloop if we run out of topologies.
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local Topology = _G.cs2.Topology

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

function LogisticsThread:enter_next_t()
	if not self.topologies then
		if self.active_topologies then
			self.topologies = tlib.t_map_a(
				self.active_topologies,
				function(_, k) return Topology.get(k) end
			)
			self.current_topology = 1
		else
			return self:set_state("init")
		end
	else
		self.current_topology = self.current_topology + 1
	end
end

function LogisticsThread:next_t(data)
	local topology = data.topologies[data.current_topology]
	if not topology then return self:set_state("init") end
	local id = topology.id
	data.nodes = tlib.t_map_a(storage.nodes, function(node)
		if node.topology_id == id then return node end
	end)
	self:set_state("poll_nodes")
end
