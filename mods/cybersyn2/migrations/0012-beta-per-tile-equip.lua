for _, layout in pairs(storage.stop_layouts) do
	if layout.cargo_loader_map then
		for key, tile_set in pairs(layout.cargo_loader_map) do
			if type(tile_set) == "number" then
				layout.cargo_loader_map[key] = { [tile_set] = true }
			end
		end
	end
	if layout.fluid_loader_map then
		for key, tile_set in pairs(layout.fluid_loader_map) do
			if type(tile_set) == "number" then
				layout.fluid_loader_map[key] = { [tile_set] = true }
			end
		end
	end
end
