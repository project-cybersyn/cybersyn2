--------------------------------------------------------------------------------
-- Train layout
--------------------------------------------------------------------------------

local events = require("lib.core.event")
local tlib = require("lib.core.table")
local counters = require("lib.core.counters")
local CarriageType = require("lib.types").CarriageType
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
	if layout_id then return layout_id end

	-- Create new layout
	---@type Cybersyn.TrainLayout
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

---Evaluate the capacity of all given trains, then re-evaluate the capacities
---of their layouts.
---@param trains Cybersyn.Train[]|nil If nil, evaluate all trains.
function cs2.evaluate_train_capacities(trains)
	if not trains then
		trains = tlib.t_map_a(storage.vehicles, function(veh)
			if veh.type == "train" and veh:is_valid() then return veh end
		end) --[[@as Cybersyn.Train[] ]]
	end
	local cache = {}
	for _, train in pairs(trains) do
		if train:evaluate_capacity() then
			events.raise("cs2.train_capacity_changed", train, cache)
		end
	end
end

--------------------------------------------------------------------------------
-- Train layout events
--------------------------------------------------------------------------------

-- On train created, assign a layout id.
cs2.on_vehicle_created(function(vehicle)
	if vehicle.type ~= "train" or (not vehicle:is_valid()) then return end
	---@cast vehicle Cybersyn.Train
	vehicle.layout_id = map_layout(vehicle)
end, true)

-- When mods change, train capacity may have changed as a result of quality
-- prototype or wagon prototype changes. Re-evaluate all capacities.
events.bind(
	"on_configuration_changed",
	function() cs2.evaluate_train_capacities() end
)
