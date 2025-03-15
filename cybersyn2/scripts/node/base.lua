node_api = {}

---@param node_id Id
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.Node?
function node_api.get_node(node_id, skip_validation)
	---@type Cybersyn.Storage
	local data = storage
	return data.nodes[node_id]
end

---Disassociate the combinator with the given id from this node, if it is
---associated.
---@param node Cybersyn.Node Reference to a *valid* node.
---@param combinator_id UnitNumber
function node_api.disassociate_combinator(node, combinator_id)
	if node.combinator_set[combinator_id] then
		node.combinator_set[combinator_id] = nil
		local comb = combinator_api.get_combinator(combinator_id, true)
		if comb and comb.node_id == node.id then
			comb.node_id = nil
			raise_combinator_node_associated(comb, nil, node)
		end
		raise_node_combinator_set_changed(node)
	end
end
