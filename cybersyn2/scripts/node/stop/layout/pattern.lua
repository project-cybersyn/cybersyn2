--------------------------------------------------------------------------------
-- Infer layout data from equipment maps.
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")

---Get car index from tile index. Assumes hard-coded length of 6 tiles per car.
---@param tile_index integer
---@return integer car_index 1-based index of car; 0 in the event of a problem.
local function get_car_index_from_tile_index(tile_index)
	if tile_index % 7 == 0 then return 0 end -- gap between cars
	local res = math.floor(tile_index / 7) + 1
	-- Users needing degenerately-long trains should use custom allowlists.
	if res < 1 or res > 32 then return 0 else return res end
end

on_train_stop_equipment_changed(function(stop, layout)
	-- TODO: I think this could theoretically be changed to allow for modded
	-- wagons, provided that those modded wagons had tile-aligned length and
	-- gap sizes. This would require some way of calculating
	-- the width in tiles of the wagons and their gaps within the train layout
	-- detection algorithm, then using that info here to build a per-tile
	-- rather than per-car pattern.

	local max_car = 1
	local layout_pattern = { 0 }
	for _, tile_index in pairs(layout.cargo_loader_map) do
		local car_index = get_car_index_from_tile_index(tile_index)
		if car_index == 0 then goto continue end
		if car_index > max_car then max_car = car_index end
		local previous_pattern = layout_pattern[car_index]
		if (previous_pattern == 2) or (previous_pattern == 3) then
			layout_pattern[car_index] = 3
		else
			layout_pattern[car_index] = 1
		end
		::continue::
	end
	for _, tile_index in pairs(layout.fluid_loader_map) do
		local car_index = get_car_index_from_tile_index(tile_index)
		if car_index == 0 then goto continue end
		if car_index > max_car then max_car = car_index end
		local previous_pattern = layout_pattern[car_index]
		if (previous_pattern == 1) or (previous_pattern == 3) then
			layout_pattern[car_index] = 3
		else
			layout_pattern[car_index] = 2
		end
		::continue::
	end
	for i = 1, max_car do
		if layout_pattern[i] == nil then layout_pattern[i] = 0 end
	end

	if tlib.a_eqeq(layout_pattern, layout.carriage_loading_pattern) then
		return
	end
	layout.carriage_loading_pattern = layout_pattern
	raise_train_stop_pattern_changed(stop, layout)
end)
