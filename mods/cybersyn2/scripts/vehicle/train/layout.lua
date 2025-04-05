--------------------------------------------------------------------------------
-- Train layout and capacity.
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
	for i = 1, #carriages do
		local carriage = carriages[i]
		names[i] = carriage.prototype.name
		types[i] = type_map[carriage.prototype.type] or CarriageType.Unknown
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
		bidirectional = (
			#(train.lua_train.locomotives["back_movers"] or empty) > 0
		),
	}
	storage.train_layouts[layout.id] = layout
	cs2.raise_train_layout_created(layout)
	return layout.id
end

---Examine the rolling stock of the train and re-compute the item and
---fluid capacity.
---@param self Cybersyn.Train A *valid* train.
function Train:evaluate_capacity()
	local carriages = self.lua_train.carriages
	local item_slot_capacity = 0
	local fluid_capacity = 0
	for i = 1, #carriages do
		local carriage = carriages[i]
		if
			carriage.type == "cargo-wagon"
			or carriage.type == "infinity-cargo-wagon"
		then
			local inventory = carriage.get_inventory(defines.inventory.cargo_wagon)
			item_slot_capacity = item_slot_capacity + #inventory
		elseif carriage.type == "fluid-wagon" then
			-- TODO: quality fluid wagon capacities
			fluid_capacity = fluid_capacity + carriage.prototype.fluid_capacity
		end
	end
	self.item_slot_capacity = item_slot_capacity
	self.fluid_capacity = fluid_capacity
end

cs2.on_vehicle_created(function(vehicle)
	if vehicle.type ~= "train" or (not vehicle:is_valid()) then return end
	---@cast vehicle Cybersyn.Train
	vehicle:evaluate_capacity()
	vehicle.layout_id = get_layout_id(vehicle)
end, true)
