--------------------------------------------------------------------------------
-- Train layout
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local tlib = require("__cybersyn2__.lib.table")
local counters = require("__cybersyn2__.lib.counters")
local CarriageType = require("__cybersyn2__.lib.types").CarriageType
local cs2 = _G.cs2

---@class Cybersyn.Train
local Train = _G.cs2.Train

local INF = math.huge

local type_map = {
	["locomotive"] = CarriageType.Locomotive,
	["cargo-wagon"] = CarriageType.CargoWagon,
	["fluid-wagon"] = CarriageType.FluidWagon,
	["artillery-wagon"] = CarriageType.ArtilleryWagon,
	["infinity-cargo-wagon"] = CarriageType.CargoWagon,
}
local empty = {}

---Get a layout id for the train, creating a new layout if needed.
---@param train Cybersyn.Train A *valid* train.
---@return Id
local function map_layout(train)
	-- Compute layout stats
	local carriages = train.lua_train.carriages
	local names = {}
	local types = {}
	local n_cargo_wagons = 0
	local n_fluid_wagons = 0
	for i = 1, #carriages do
		local carriage = carriages[i]
		names[i] = carriage.prototype.name
		local carriage_type = type_map[carriage.prototype.type]
			or CarriageType.Unknown
		types[i] = carriage_type
		if carriage_type == CarriageType.CargoWagon then
			n_cargo_wagons = n_cargo_wagons + 1
		elseif carriage_type == CarriageType.FluidWagon then
			n_fluid_wagons = n_fluid_wagons + 1
		end
	end

	-- Check if layout exists
	local _, layout_id = tlib.find(storage.train_layouts, function(layout)
		if tlib.a_eqeq(layout.carriage_names, names) then return true end
	end)
	if layout_id then
		local layout = storage.train_layouts[layout_id]
		-- Update minimum capacities if needed
		local changed = false
		if (train.fluid_capacity or 0) > 0 then
			if
				not layout.min_fluid_capacity
				or (train.fluid_capacity < layout.min_fluid_capacity)
			then
				layout.min_fluid_capacity = train.fluid_capacity
				changed = true
			end
		end
		if (train.item_slot_capacity or 0) > 0 then
			if
				not layout.min_item_slot_capacity
				or (train.item_slot_capacity < layout.min_item_slot_capacity)
			then
				layout.min_item_slot_capacity = train.item_slot_capacity
				changed = true
			end
		end
		if changed then cs2.raise_train_layout_changed(layout) end
		return layout_id
	end

	-- Create new layout
	local min_fluid_capacity = nil
	local min_item_slot_capacity = nil
	if (train.fluid_capacity or 0) > 0 then
		min_fluid_capacity = train.fluid_capacity
	end
	if (train.item_slot_capacity or 0) > 0 then
		min_item_slot_capacity = train.item_slot_capacity
	end

	---@type Cybersyn.TrainLayout
	local layout = {
		id = counters.next("train_layout"),
		carriage_names = names,
		carriage_types = types,
		n_cargo_wagons = n_cargo_wagons,
		n_fluid_wagons = n_fluid_wagons,
		min_fluid_capacity = min_fluid_capacity,
		min_item_slot_capacity = min_item_slot_capacity,
		bidirectional = (
			#(train.lua_train.locomotives["back_movers"] or empty) > 0
		),
	}
	storage.train_layouts[layout.id] = layout
	cs2.raise_train_layout_created(layout)
	return layout.id
end

---@param layout Cybersyn.TrainLayout
local function evaluate_layout_capacities(layout)
	local min_fluid_capacity = nil
	local min_item_slot_capacity = nil
	for _, train in pairs(storage.vehicles) do
		if train.type == "train" then
			---@cast train Cybersyn.Train
			if train:is_valid() and train.layout_id == layout.id then
				local fluid_capacity = train.fluid_capacity or 0
				local item_slot_capacity = train.item_slot_capacity or 0
				if
					fluid_capacity > 0
					and fluid_capacity < (min_fluid_capacity or INF)
				then
					min_fluid_capacity = fluid_capacity
				end
				if
					item_slot_capacity > 0
					and item_slot_capacity < (min_item_slot_capacity or INF)
				then
					min_item_slot_capacity = item_slot_capacity
				end
			end
		end
	end
	layout.min_fluid_capacity = min_fluid_capacity
	layout.min_item_slot_capacity = min_item_slot_capacity
	cs2.raise_train_layout_changed(layout)
end

---Evaluate the capacity of all given trains, then re-evaluate the capacities
---of their layouts.
---@param trains Cybersyn.Train[]|nil If nil, evaluate all trains.
function cs2.evaluate_train_capacities(trains)
	if not trains then
		trains = tlib.t_map_a(storage.vehicles, function(veh)
			if veh.type == "train" and veh:is_valid() then return veh end
		end) --[[@as Cybersyn.Train[] ]]
	end
	local seen_layouts = {}
	for _, train in pairs(trains) do
		train:evaluate_capacity()
		if train.layout_id then seen_layouts[train.layout_id] = true end
	end
	for layout_id in pairs(seen_layouts) do
		local layout = storage.train_layouts[layout_id]
		if layout then evaluate_layout_capacities(layout) end
	end
end

--------------------------------------------------------------------------------
-- Train layout events
--------------------------------------------------------------------------------

-- On train created, evaluate the capacity and assign a layout id.
cs2.on_vehicle_created(function(vehicle)
	if vehicle.type ~= "train" or (not vehicle:is_valid()) then return end
	---@cast vehicle Cybersyn.Train
	vehicle:evaluate_capacity()
	vehicle.layout_id = map_layout(vehicle)
end, true)

-- When mods change, train capacity may have changed as a result of quality
-- prototype or wagon prototype changes. Re-evaluate all capacities.
cs2.on_configuration_changed(function() cs2.evaluate_train_capacities() end)
