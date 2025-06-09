--------------------------------------------------------------------------------
-- Base classes and methods for Vehicles.
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local counters = require("__cybersyn2__.lib.counters")

local cs2 = _G.cs2

---@class Cybersyn.Vehicle
local Vehicle = class("Vehicle")
_G.cs2.Vehicle = Vehicle

---Creates and stores a new vehicle state. Does not fire any events; this
---is delegated to constructors of specific vehicle types.
---@param type string
---@return Cybersyn.Vehicle
function Vehicle.new(type)
	local id = counters.next("vehicle")
	storage.vehicles[id] =
		setmetatable({ id = id, type = type, created_tick = game.tick }, Vehicle)
	return storage.vehicles[id]
end

---Determine if the vehicle is valid.
---@return boolean
function Vehicle:is_valid() return false end

---@param id Id?
---@param skip_validation? boolean If `true`, return contents of storage without validation.
function Vehicle.get(id, skip_validation)
	if not id then return nil end
	local vehicle = storage.vehicles[id]
	if skip_validation then
		return vehicle
	else
		return vehicle:is_valid() and vehicle or nil
	end
end

---@return table<Id, Cybersyn.Vehicle>
function Vehicle.all() return storage.vehicles end

---Determine if the vehicle is available for processing a delivery
---@return boolean
function Vehicle:is_available() return false end

function Vehicle:destroy()
	self.is_being_destroyed = true
	cs2.raise_vehicle_destroyed(self)
	storage.vehicles[self.id] = nil
end
