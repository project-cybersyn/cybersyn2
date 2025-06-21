--------------------------------------------------------------------------------
-- Base Train class and associated structures
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local train_lib = require("__cybersyn2__.lib.trains")
local cs2 = _G.cs2
local Vehicle = _G.cs2.Vehicle
local Topology = _G.cs2.Topology

local strsub = string.sub
local mod_settings = _G.cs2.mod_settings

--------------------------------------------------------------------------------
-- Group tracking
--------------------------------------------------------------------------------

---@class Cybersyn.Internal.TrainGroup
---@field public name string The factorio train group name.
---@field public trains IdSet The set of vehicle ids of trains in the group.
---@field public topology_id Id? The id of the topology manually assigned to this group, if any.

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
	-- Check for topology name after group name
	local prefix = cs2.CYBERSYN_TRAIN_GROUP_NAME_PREFIX
	local rest = strsub(name or "", #prefix + 1)
	local _, _, signal = string.find(rest, "^(%[virtual%-signal=[%w_%-]+%])")
	local topology_id = nil
	if signal then
		local topology = cs2.get_or_create_topology_by_name(signal)
		topology_id = topology.id
	end

	storage.train_groups[name] = {
		name = name,
		trains = {},
		topology_id = topology_id,
	}
	-- cs2.raise_train_group_created(name)
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
			-- cs2.raise_train_group_train_removed(vehicle, name)
		end
	end
	storage.train_groups[name] = nil
	-- cs2.raise_train_group_destroyed(name)
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
		-- cs2.raise_train_group_train_added(vehicle)
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
		-- cs2.raise_train_group_train_removed(vehicle, group_name)
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

	local topology = Topology.get_train_topology(stock.surface_index)
	if not topology then return nil end

	local train = Vehicle.new("train") --[[@as Cybersyn.Train]]
	setmetatable(train, Train)
	train.lua_train = lua_train
	train.stock = stock
	train.lua_train_id = lua_train.id
	train.topology_id = topology.id
	train.home_surface_index = stock.surface_index
	train.item_slot_capacity = 0
	train.fluid_capacity = 0

	storage.luatrain_id_to_vehicle_id[lua_train.id] = train.id
	cs2.raise_vehicle_created(train)
	return train
end

function Train.get(id, skip_validation)
	local train = Vehicle.get(id, skip_validation)
	if train and train.type == "train" then
		return train --[[@as Cybersyn.Train]]
	else
		return nil
	end
end

---Get a `Cybersyn.Train` from a Factorio `LuaTrain` object.
---@param luatrain_id Id?
---@return Cybersyn.Train?
function Train.get_from_luatrain_id(luatrain_id)
	local vid = storage.luatrain_id_to_vehicle_id[luatrain_id or ""]
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

function Train:get_stock()
	-- TODO: volatility
	return self.stock
end

---@param delivery Cybersyn.TrainDelivery
function Train:set_delivery(delivery) self.delivery_id = delivery.id end

---@param id Id
function Train:clear_delivery(id)
	if self.delivery_id == id then self.delivery_id = nil end
end

function Train:fail_delivery(id) return self:clear_delivery(id) end

---@param schedule LuaSchedule
---@return boolean in_interrupt `true` if the schedule is currently interrupted
---@return boolean in_depot `true` if the active schedule entry is the depot
local function get_schedule_state(schedule)
	local current_record =
		schedule.get_record({ schedule_index = schedule.current })
	if current_record then
		if current_record.created_by_interrupt then
			return true, false
		elseif not current_record.temporary then
			return false, true
		end
	end
	return false, false
end

---@param schedule LuaSchedule
---@param record AddRecordData
local function add_temp_record(schedule, record)
	local record_count = schedule.get_record_count()
	local index = record_count > 0 and record_count or 1
	record.index = { schedule_index = index }
	record.temporary = true
	schedule.add_record(record)
end

---Add temporary records to the train's schedule.
---@return boolean
function Train:schedule(...)
	local schedule = self.lua_train.get_schedule()
	local is_interrupted, is_depot = get_schedule_state(schedule)
	if is_interrupted then return false end
	for i = 1, select("#", ...) do
		local record = select(i, ...)
		add_temp_record(schedule, record)
	end
	if is_depot then schedule.go_to_station(1) end
	return true
end

function Train:is_available()
	if self.delivery_id or not self:is_valid() then return false end
	-- Honor vehicle warmup time
	if
		game.tick - (self.created_tick or 0)
		< (mod_settings.vehicle_warmup_time * 60)
	then
		return false
	end
	local schedule = self.lua_train.get_schedule()
	if get_schedule_state(schedule) then return false end
	return true
end

---@return int n_cargo_wagons Number of cargo wagons
---@return int n_fluid_wagons Number of fluid wagons
function Train:get_wagon_counts()
	local layout = storage.train_layouts[self.layout_id]
	if layout then
		return layout.n_cargo_wagons, layout.n_fluid_wagons
	else
		return 0, 0
	end
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
		local ic, fc = train_lib.get_carriage_capacity(carriage)
		item_slot_capacity = item_slot_capacity + ic
		fluid_capacity = fluid_capacity + fc
	end
	self.item_slot_capacity = item_slot_capacity
	self.fluid_capacity = fluid_capacity
	-- These will be recomputed on demand by wagon control subsystem.
	self.per_wagon_fluid_capacity = nil
	self.per_wagon_item_slot_capacity = nil
end
