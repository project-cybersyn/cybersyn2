-- Recalculate stop capacity for all stops
for _, node in pairs(storage.nodes) do
	if node.type == "stop" then
		---@cast node Cybersyn.TrainStop
		node:evaluate_allowed_capacities()
	end
end
