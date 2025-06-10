-- Create empty log buffers for pre-existing nodes
for _, node in pairs(storage.nodes) do
	node.log_buffer = node.log_buffer or {}
	node.log_current = node.log_current or 1
	node.log_size = node.log_size or 10
end
