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
local function get_layout_id(train)
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
	if layout_id then return layout_id end

	local layout = {
		id = counters.next("train_layout"),
		carriage_names = names,
		carriage_types = types,
		n_cargo_wagons = n_cargo_wagons,
		n_fluid_wagons = n_fluid_wagons,
		bidirectional = (
			#(train.lua_train.locomotives["back_movers"] or empty) > 0
		),
	}
	storage.train_layouts[layout.id] = layout
	cs2.raise_train_layout_created(layout)
	return layout.id
end

--------------------------------------------------------------------------------
-- Train layout events
--------------------------------------------------------------------------------

-- On train created, evaluate the capacity and assign a layout id.
cs2.on_vehicle_created(function(vehicle)
	if vehicle.type ~= "train" or (not vehicle:is_valid()) then return end
	---@cast vehicle Cybersyn.Train
	vehicle:evaluate_capacity()
	vehicle.layout_id = get_layout_id(vehicle)
end, true)

-- When mods change, train capacity may have changed as a result of quality
-- prototype or wagon prototype changes. Re-evaluate all capacities.
cs2.on_configuration_changed(function()
	for _, veh in pairs(storage.vehicles) do
		if veh.type == "train" and veh:is_valid() then
			---@cast veh Cybersyn.Train
			veh:evaluate_capacity()
		end
	end
end)
