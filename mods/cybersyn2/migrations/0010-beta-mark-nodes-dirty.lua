for _, comb in pairs(storage.combinators) do
	comb.inputs_dirty = true
end

for _, node in pairs(storage.nodes) do
	node.poll_dirty = true
end
