for surface_index, topology_id in pairs(storage.surface_index_to_train_topology) do
	local topology = storage.topologies[topology_id]
	if topology then topology.surface_set = { [surface_index] = true } end
end

for _, topology in pairs(storage.topologies) do
	if not topology.surface_set then topology.surface_set = {} end
end
