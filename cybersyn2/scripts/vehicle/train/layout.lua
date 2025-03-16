--------------------------------------------------------------------------------
-- Train layout and capacity.
--------------------------------------------------------------------------------
local log = require("__cybersyn2__.lib.logging")
local tlib = require("__cybersyn2__.lib.table")
local counters = require("__cybersyn2__.lib.counters")
local CarriageType = require("__cybersyn2__.lib.types").CarriageType

local type_map = {
	["locomotive"] = CarriageType.Locomotive,
	["cargo-wagon"] = CarriageType.CargoWagon,
	["fluid-wagon"] = CarriageType.FluidWagon,
	["artillery-wagon"] = CarriageType.ArtilleryWagon,
	["infinity-cargo-wagon"] = CarriageType.CargoWagon,
}
local empty = {}

local function array_eq(a1, a2)
	if #a1 ~= #a2 then return false end
	for i = 1, #a1 do
		if a1[i] ~= a2[i] then return false end
	end
	return true
end

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
	local data = storage --[[@as Cybersyn.Storage]]
	local _, layout_id = tlib.find(data.train_layouts, function(layout)
		if array_eq(layout.carriage_names, names) then
			return true
		end
	end)
	if layout_id then return layout_id end

	local layout = {
		id = counters.next("train_layout"),
		carriage_names = names,
		carriage_types = types,
		bidirectional = (#(train.lua_train.locomotives["back_movers"] or empty) > 0),
	}
	data.train_layouts[layout.id] = layout
	raise_train_layout_created(layout)
	return layout.id
end

---Examine the rolling stock of the train and re-compute the item and
---fluid capacity.
---@param train Cybersyn.Train A *valid* train.
function train_api.evaluate_capacity(train)
	local carriages = train.lua_train.carriages
	local item_slot_capacity = 0
	local fluid_capacity = 0
	for i = 1, #carriages do
		local carriage = carriages[i]
		if carriage.type == "cargo-wagon" or carriage.type == "infinity-cargo-wagon" then
			local inventory = carriage.get_inventory(defines.inventory.cargo_wagon)
			item_slot_capacity = item_slot_capacity + #inventory
		elseif carriage.type == "fluid-wagon" then
			fluid_capacity = fluid_capacity + carriage.prototype.fluid_capacity
		end
	end
	train.item_slot_capacity = item_slot_capacity
	train.fluid_capacity = fluid_capacity
end

on_vehicle_created(function(vehicle)
	local train = vehicle --[[@as Cybersyn.Train]]
	if not train_api.is_valid(train) then
		log.warn("Train %d is not valid, ignoring.", vehicle.id)
		return
	end
	train_api.evaluate_capacity(train)
	train.layout_id = get_layout_id(train)
end, true)
