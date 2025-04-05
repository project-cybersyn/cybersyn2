--------------------------------------------------------------------------------
-- Base Train class and associated structures
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local cs2 = _G.cs2
local node_api = _G.cs2.node_api
local Vehicle = _G.cs2.Vehicle

local strsub = string.sub

--------------------------------------------------------------------------------
-- Group tracking
--------------------------------------------------------------------------------

---Check if the given group name is considered a Cybersyn train group name.
---@param name string?
---@return boolean
local function is_cybersyn_train_group_name(name)
	local prefix = cs2.CYBERSYN_TRAIN_GROUP_NAME_PREFIX
	return strsub(name or "", 1, #prefix) == prefix
end
_G.cs2.is_cybersyn_train_group_name = is_cybersyn_train_group_name

---@param name string
local function create_train_group(name)
	storage.train_groups[name] = {
		name = name,
		trains = {},
	}
	cs2.raise_train_group_created(name)
end
_G.cs2.create_train_group = create_train_group

---@param name string
local function destroy_train_group(name)
	local group = storage.train_groups[name]
	if not group then return end
	for vehicle_id in pairs(group.trains) do
		group.trains[vehicle_id] = nil
		local vehicle = storage.vehicles[vehicle_id] --[[@as Cybersyn.Train]]
		if vehicle and vehicle.group == name then
			vehicle.group = nil
			cs2.raise_train_group_train_removed(vehicle, name)
		end
	end
	storage.train_groups[name] = nil
	cs2.raise_train_group_destroyed(name)
end
_G.cs2.destroy_train_group = destroy_train_group

---@param vehicle Cybersyn.Train
---@param group_name string
local function add_train_to_group(vehicle, group_name)
	if (not vehicle) or not group_name then return end
	local group = storage.train_groups[group_name]
	vehicle.group = group_name
	if group and not group.trains[vehicle.id] then
		group.trains[vehicle.id] = true
		cs2.raise_train_group_train_added(vehicle)
	end
end
_G.cs2.add_train_to_group = add_train_to_group

local function remove_train_from_group(vehicle, group_name)
	if (not vehicle) or not group_name then return end
	local group = storage.train_groups[group_name]
	vehicle.group = nil
	if not group then return end
	if group.trains[vehicle.id] then
		group.trains[vehicle.id] = nil
		cs2.raise_train_group_train_removed(vehicle, group_name)
	end
	if not next(group.trains) then
		-- Group is now empty, destroy it
		destroy_train_group(group_name)
	end
end
_G.cs2.remove_train_from_group = remove_train_from_group

---@param group_name string
function _G.cs2.get_train_group(group_name)
	return storage.train_groups[group_name]
end

--------------------------------------------------------------------------------
-- Train
--------------------------------------------------------------------------------

---@class Cybersyn.Train
local Train = class("Train", _G.cs2.Vehicle)
_G.cs2.Train = Train

---Create a new `Train` abstraction from a `LuaTrain`.
---@param lua_train LuaTrain A *valid* `LuaTrain`
---@return Cybersyn.Train?
function Train.new(lua_train)
	local preexisting_id = storage.luatrain_id_to_vehicle_id[lua_train.id]
	if preexisting_id then
		local preexisting = storage.vehicles[preexisting_id]
		if preexisting and preexisting.type == "train" then
			return preexisting --[[@as Cybersyn.Train]]
		else
			return nil
		end
	end

	local stock = lua_train.valid
		and (
			lua_train.front_stock
			or lua_train.back_stock
			or lua_train.carriages[1]
		)
	if not stock then return nil end

	local topology = node_api.get_train_topology(stock.surface_index)
	if not topology then return nil end

	local train = Vehicle.new("train") --[[@as Cybersyn.Train]]
	train.lua_train = lua_train
	train.stock = stock
	train.lua_train_id = lua_train.id
	train.topology_id = topology.id
	train.item_slot_capacity = 0
	train.fluid_capacity = 0

	storage.luatrain_id_to_vehicle_id[lua_train.id] = train.id
	cs2.raise_vehicle_created(train)
	return train
end

---Get a `Cybersyn.Train` from a Factorio `LuaTrain` object.
---@param luatrain LuaTrain A *valid* `LuaTrain`.
---@return Cybersyn.Train?
function Train.get_from_luatrain(luatrain)
	if (not luatrain) or not luatrain.valid then return nil end
	local vid = storage.luatrain_id_to_vehicle_id[luatrain.id]
	if not vid then return nil end
	return storage.vehicles[vid] --[[@as Cybersyn.Train]]
end

function Train:destroy()
	self.is_being_destroyed = true
	if self.group then remove_train_from_group(self, self.group) end
	if self.lua_train_id then
		storage.luatrain_id_to_vehicle_id[self.lua_train_id] = nil
	end
	if self.lua_train and self.lua_train.valid then
		storage.luatrain_id_to_vehicle_id[self.lua_train.id] = nil
	end
	Vehicle.destroy(self)
end

function Train:is_valid()
	if
		self.lua_train
		and self.lua_train.valid
		and not self.is_being_destroyed
	then
		return true
	else
		return false
	end
end

function Train:is_volatile()
	if self.volatile and not self.is_being_destroyed then
		return true
	else
		return false
	end
end

function Train:get_stock() return self.stock end
