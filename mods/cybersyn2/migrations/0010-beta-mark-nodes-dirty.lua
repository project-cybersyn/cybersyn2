for _, comb in pairs(storage.combinators) do
	comb.inputs_dirty = true
end

for _, node in pairs(storage.nodes) do
	node:mark_dirty()
end
