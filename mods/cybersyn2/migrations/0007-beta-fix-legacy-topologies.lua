for _, group in pairs(storage.train_groups) do
	if group.topology_id and not group.topology then group.topology_id = nil end
end
