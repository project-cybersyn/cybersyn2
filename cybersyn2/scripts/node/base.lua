--------------------------------------------------------------------------------
-- Base API for Cybersyn `Node` objects.
--------------------------------------------------------------------------------
local tlib = require("__cybersyn2__.lib.table")
local log = require("__cybersyn2__.lib.logging")

node_api = {}

---@param node_id Id?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.Node?
function node_api.get_node(node_id, skip_validation)
	if not node_id then return nil end
	return storage.nodes[node_id]
end

---Associate the given combinator with the given node.
---@param node Cybersyn.Node? Reference to a *valid* node.
---@param combinator Cybersyn.Combinator.Internal Reference to a *valid* combinator.
---@param suppress_set_changed boolean? If `true`, does not raise the `node_combinator_set_changed` event. You must do so yourself if performing a batch of updates.
---@return boolean success `true` if the combinator was successfully associated, `false` if not.
---@return Cybersyn.Node? old_node The node that the combinator was previously associated with, if any.
function node_api.associate_combinator(node, combinator, suppress_set_changed)
	if not node then return false end
	local old_node
	if combinator.node_id and combinator.node_id ~= node.id then
		-- Combinator is already associated with a different node.
		old_node = node_api.get_node(combinator.node_id, true)
		node_api.disassociate_combinator(combinator, suppress_set_changed)
	end

	if not node.combinator_set[combinator.id] then
		node.combinator_set[combinator.id] = true
		combinator.node_id = node.id
		raise_combinator_node_associated(combinator, node, nil)
		if not suppress_set_changed then
			raise_node_combinator_set_changed(node)
		end
		return true, old_node
	end

	return false, old_node
end

---Disassociate the given combinator from its associated node if any.
---@param combinator Cybersyn.Combinator.Internal? Reference to a *valid* combinator.
---@param suppress_set_changed boolean? If `true`, does not raise the `node_combinator_set_changed` event. You must do so yourself if performing a batch of updates.
---@return Cybersyn.Node? old_node If the combinator was disassociated, the node that it was disassociated from, otherwise `nil`.
function node_api.disassociate_combinator(combinator, suppress_set_changed)
	if not combinator then return nil end
	local node = node_api.get_node(combinator.node_id, true)
	combinator.node_id = nil
	if not node then return nil end
	if not node.combinator_set[combinator.id] then
		log.error("referential inconsistency between associated combinator and node combinator set")
		return nil
	end
	node.combinator_set[combinator.id] = nil
	raise_combinator_node_associated(combinator, nil, node)
	if not suppress_set_changed then
		raise_node_combinator_set_changed(node)
	end
	return node
end

---Get all combinators associated with this node.
---@param node Cybersyn.Node Reference to a *valid* node.
---@return Cybersyn.Combinator.Internal[] #The combinators associated to the node, if any.
function node_api.get_associated_combinators(node)
	return tlib.t_map_a(node.combinator_set, function(_, combinator_id)
		return combinator_api.get_combinator(combinator_id, true)
	end)
end
