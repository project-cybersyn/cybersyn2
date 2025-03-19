--------------------------------------------------------------------------------
-- Train lifecycle.
--------------------------------------------------------------------------------

local scheduler = require("__cybersyn2__.lib.scheduler")
local log = require("__cybersyn2__.lib.logging")
local counters = require("__cybersyn2__.lib.counters")

local ALL_TRAINS_FILTER = {}

---@param lua_train LuaTrain A *valid* `LuaTrain`.
---@return Cybersyn.Train? #The created train object if it was possible to create it.
local function create_train(lua_train)
	local preexisting_id = storage.luatrain_id_to_vehicle_id[lua_train.id]
	if preexisting_id then
		local preexisting = storage.vehicles[preexisting_id]
		if preexisting and preexisting.type == "train" then
			return preexisting --[[@as Cybersyn.Train]]
		else
			return nil
		end
	end

	local vehicle = {
		id = counters.next("vehicle"),
		type = "train",
		lua_train = lua_train,
		lua_train_id = lua_train.id,
	}
	storage.vehicles[vehicle.id] = vehicle
	storage.luatrain_id_to_vehicle_id[lua_train.id] = vehicle.id

	raise_vehicle_created(vehicle)
	return vehicle
end

---@param name string
local function create_train_group(name)
	storage.train_groups[name] = {
		name = name,
		trains = {},
	}
	raise_train_group_created(name)
end

---@param name string
local function destroy_train_group(name)
	local group = storage.train_groups[name]
	if not group then return end
	for vehicle_id in pairs(group.trains) do
		group.trains[vehicle_id] = nil
		local vehicle = storage.vehicles[vehicle_id] --[[@as Cybersyn.Train]]
		if vehicle and vehicle.group == name then
			vehicle.group = nil
			raise_train_group_train_removed(vehicle, name)
		end
	end
	storage.train_groups[name] = nil
	raise_train_group_destroyed(name)
end

---@param vehicle Cybersyn.Train
---@param group_name string
local function add_train_to_group(vehicle, group_name)
	if (not vehicle) or (not group_name) then return end
	local group = storage.train_groups[group_name]
	vehicle.group = group_name
	if group and (not group.trains[vehicle.id]) then
		group.trains[vehicle.id] = true
		raise_train_group_train_added(vehicle)
	end
end

local function remove_train_from_group(vehicle, group_name)
	if (not vehicle) or (not group_name) then return end
	local group = storage.train_groups[group_name]
	vehicle.group = nil
	if not group then return end
	if group.trains[vehicle.id] then
		group.trains[vehicle.id] = nil
		raise_train_group_train_removed(vehicle, group_name)
	end
	if not next(group.trains) then
		-- Group is now empty, destroy it
		destroy_train_group(group_name)
	end
end

---@param vehicle_id Id?
local function destroy_train(vehicle_id)
	if not vehicle_id then return end
	vehicle = storage.vehicles[vehicle_id] --[[@as Cybersyn.Train]]
	if not vehicle then return end
	vehicle.is_being_destroyed = true
	if vehicle.group then remove_train_from_group(vehicle, vehicle.group) end
	if vehicle.lua_train_id then
		storage.luatrain_id_to_vehicle_id[vehicle.lua_train_id] = nil
	end
	if vehicle.lua_train and vehicle.lua_train.valid then
		storage.luatrain_id_to_vehicle_id[vehicle.lua_train.id] = nil
	end
	raise_vehicle_destroyed(vehicle)
	storage.vehicles[vehicle.id] = nil
end

--------------------------------------------------------------------------------
-- Train group monitor background thread
--------------------------------------------------------------------------------
---@class (exact) Cybersyn.Internal.TrainMonitorTaskData
---@field state "init"|"enum_luatrains"|"enum_cstrains" State of the task.
---@field stride int The number of trains to process per iteration
---@field index int The current index in the enumeration.
---@field trains LuaTrain[] Extant luatrains at beginning of sweep.
---@field seen_groups table<string, true> Cybersyn groups seen by sweep.
---@field train_ids Id[] Extant Cybersyn train vehicle IDs at beginning of sweep.

---@class Cybersyn.Internal.TrainMonitorTask: Scheduler.RecurringTask
---@field public data Cybersyn.Internal.TrainMonitorTaskData

---@param data Cybersyn.Internal.TrainMonitorTaskData
local function monitor_init(data)
	data.stride = math.ceil(PERF_TRAIN_GROUP_MONITOR_WORKLOAD * mod_settings.work_factor)
	data.index = 1
	data.seen_groups = {}
	if game and game.train_manager then
		data.trains = game.train_manager.get_trains(ALL_TRAINS_FILTER)
		data.train_ids = train_api.get_all_train_ids()
		data.state = "enum_luatrains"
	end
end

---@param luatrain LuaTrain
---@param data Cybersyn.Internal.TrainMonitorTaskData
local function monitor_enum_luatrain(luatrain, data)
	if (not luatrain) or (not luatrain.valid) then return end
	local group_name = luatrain.group
	local vehicle = train_api.get_train_from_luatrain(luatrain)

	-- If train has no group, remove it if we know about it
	if not group_name then
		destroy_train(vehicle and vehicle.id)
		return
	end

	data.seen_groups[group_name] = true
	local group = train_api.get_train_group(group_name)
	if group then
		if vehicle then
			if vehicle.group == group_name then
				-- Train is in the right group, nothing to do.
				return
			else
				-- Train is in a group, but not the one we expect. Remove it from the old group
				remove_train_from_group(vehicle, vehicle.group)
			end
		end
	else
		-- Group is not a known cybersyn group...
		if train_api.is_cybersyn_train_group_name(group_name) then
			create_train_group(group_name)
		else
			-- Train is in a non-cybersyn group. If we know about it, remove it.
			destroy_train(vehicle and vehicle.id)
			return
		end
	end

	-- If we reach here, we need to add the train to the game if it doesnt
	-- exist, then add it to the designated group.
	if not vehicle then vehicle = create_train(luatrain) end
	if not vehicle then
		-- Strange situation; vehicle already exists?
		log.debug("Encountered supposedly impossible condition while create_train()", luatrain)
		return
	end
	add_train_to_group(vehicle, group_name)
end

---@param data Cybersyn.Internal.TrainMonitorTaskData
local function monitor_enum_luatrains(data)
	local max_index = math.min(data.index + data.stride, #data.trains)
	for i = data.index, max_index do
		monitor_enum_luatrain(data.trains[i], data)
	end
	if max_index >= #data.trains then
		data.state = "enum_cstrains"
		data.index = 1
		data.trains = nil
	else
		data.index = max_index + 1
	end
end

local function monitor_enum_cstrain(vehicle_id, data)
	if not vehicle_id then return end
	local train = train_api.get_train(vehicle_id)
	-- `nil` here means train couldn't be validated, destroy it
	if not train then destroy_train(vehicle_id) end
end

local function monitor_enum_cstrains(data)
	local max_index = math.min(data.index + data.stride, #data.train_ids)
	for i = data.index, max_index do
		monitor_enum_cstrain(data.train_ids[i], data)
	end
	if max_index >= #data.train_ids then
		data.state = "init"
		data.index = nil
		data.train_ids = nil
	else
		data.index = max_index + 1
	end
end

---@param task Cybersyn.Internal.TrainMonitorTask
local function train_group_monitor(task)
	local data = task.data
	if data.state == "init" then
		monitor_init(data)
	elseif data.state == "enum_luatrains" then
		monitor_enum_luatrains(data)
	elseif data.state == "enum_cstrains" then
		monitor_enum_cstrains(data)
	else
		log.error("Invalid train group monitor task state:", data.state)
	end
end

threads_api.schedule_thread("train_group_monitor", train_group_monitor, 1)
