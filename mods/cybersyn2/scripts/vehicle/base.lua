--------------------------------------------------------------------------------
-- Base classes and methods for Vehicles.
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local counters = require("lib.core.counters")
local events = require("lib.core.event")

local cs2 = _G.cs2

local rcall = remote.call

--------------------------------------------------------------------------------
-- Busy_plugins
--------------------------------------------------------------------------------

local busy_plugins = prototypes.mod_data["cybersyn2"].data.busy_plugins --[[@as Core.RemoteCallbackSpec[] ]]

---@param vehicle_id Id
---@param lua_train LuaTrain?
---@return boolean
function _G.cs2.query_busy_plugins(vehicle_id, lua_train)
	for i = 1, #busy_plugins do
		local plugin = busy_plugins[i]
		if rcall(plugin[1], plugin[2], vehicle_id, lua_train) then return true end
	end
	return false
end

--------------------------------------------------------------------------------
-- Vehicle
--------------------------------------------------------------------------------

---@class (partial) Cybersyn.Vehicle
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
	elseif vehicle then
		return vehicle:is_valid() and vehicle or nil
	end
	return nil
end

---@return {[Id]: Cybersyn.Vehicle}
function Vehicle.all() return storage.vehicles end

---Determine if the vehicle is available for processing a delivery
---@return boolean
function Vehicle:is_available() return false end

---This function is called by the dispatcher thread on the very frame
---it is about to dispatch a vehicle that was previously deemed available
---and gives a chance to do last-second checks to ensure nothing changed
---asynchronously. Only things that could've changed in a few frames since
---`is_available` should be checked here.
---@return boolean
function Vehicle:late_is_available() return false end

function Vehicle:destroy()
	self.is_being_destroyed = true
	cs2.raise_vehicle_destroyed(self)
	events.raise("cs2.vehicle_destroyed", self)
	storage.vehicles[self.id] = nil
end

--------------------------------------------------------------------------------
-- Topology
--------------------------------------------------------------------------------

---@param topology_id Id?
---@return boolean was_set `true` if the topology was changed from the previous effective topology.
function Vehicle:set_topology(topology_id)
	local previous_topology_id = self.topology_id
	if previous_topology_id == topology_id then return false end
	local previous_effective_topology_id = previous_topology_id
		or self.default_topology_id
	self.topology_id = topology_id
	local current_effective_topology_id = topology_id or self.default_topology_id
	if previous_effective_topology_id ~= current_effective_topology_id then
		events.raise(
			"cs2.vehicle_topology_changed",
			self,
			previous_effective_topology_id
		)
		return true
	end
	return false
end

---@param topology_id Id?
function Vehicle:set_default_topology(topology_id)
	local previous_dt = self.default_topology_id
	if previous_dt == topology_id then return end
	self.default_topology_id = topology_id
	if self.topology_id == nil then
		events.raise("cs2.vehicle_topology_changed", self, previous_dt)
	end
end

---@return boolean was_set `true` if the default topology was set.
function Vehicle:compute_default_topology()
	local plugin_id = cs2.query_vehicle_topology_plugins(self)
	if plugin_id then
		self:set_default_topology(plugin_id)
		return true
	end

	return false
end

---@return Id? topology_id Id of the topology this vehicle belongs to, if any.
function Vehicle:get_topology_id()
	return self.topology_id or self.default_topology_id
end
