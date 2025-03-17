--------------------------------------------------------------------------------
-- Lifecycle for `Node`s
--------------------------------------------------------------------------------
local counters = require("__cybersyn2__.lib.counters")
local tlib = require("__cybersyn2__.lib.table")

---Create a new node. This should be used internally by providers of specific
---kinds of node, such as train stops.
---@param node_type string
---@param initial_data table #Initial state data appropriate to the node type which will be assigned to the new node.
function node_api.create_node(node_type, initial_data)
	local id = counters.next("node")
	initial_data.id = id
	initial_data.type = node_type
	initial_data.combinator_set = {}
	initial_data.is_being_destroyed = nil
	storage.nodes[id] = initial_data

	raise_node_created(storage.nodes[id])
	return storage.nodes[id]
end

---Destroy the node with the given id.
---@param node_id Id
function node_api.destroy_node(node_id)
	local node = node_api.get_node(node_id, true)
	if not node then return end

	node.is_being_destroyed = true
	raise_node_destroyed(node)

	-- If type-specific destructors bound to the event failed to clear the
	-- combinator set, we must do so here.
	if next(node.combinator_set) then
		tlib.for_each(node.combinator_set, function(_, combinator_id)
			local combinator = combinator_api.get_combinator(combinator_id, true)
			node_api.disassociate_combinator(combinator, true)
		end)
		raise_node_combinator_set_changed(node)
	end

	-- Destroy state
	storage.nodes[node_id] = nil
end

-- When a combinator is destroyed, disassociate it from its node.
on_combinator_destroyed(function(combinator)
	if combinator.node_id then
		node_api.disassociate_combinator(combinator)
	end
end)
