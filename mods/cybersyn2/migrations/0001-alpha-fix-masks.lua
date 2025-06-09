-- Update network masks to bitmasks.

for _, node in pairs(storage.nodes) do
	if node.default_networks then
		for network_name, mask in pairs(node.default_networks) do
			if mask == true then node.default_networks[network_name] = -1 end
		end
	end
end

for _, inventory in pairs(storage.inventories) do
	if inventory.orders then
		for _, order in pairs(inventory.orders) do
			if order.networks then
				for network_name, mask in pairs(order.networks) do
					if mask == true then order.networks[network_name] = -1 end
				end
			end
		end
	end
end
