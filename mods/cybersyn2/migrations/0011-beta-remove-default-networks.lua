-- Remove deprecated default_networks from nodes. This was used in the past to set default networks for a node, but now networks are set at the order level.

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

for _, node in pairs(storage.nodes) do
	---@diagnostic disable-next-line: inject-field
	node.default_networks = nil
end
