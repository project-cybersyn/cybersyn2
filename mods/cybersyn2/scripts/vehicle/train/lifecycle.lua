--------------------------------------------------------------------------------
-- Train lifecycle.
--------------------------------------------------------------------------------

local scheduler = require("__cybersyn2__.lib.scheduler")
local log = require("__cybersyn2__.lib.logging")
local stlib = require("__cybersyn2__.lib.strace")
local counters = require("__cybersyn2__.lib.counters")
local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings
local Train = _G.cs2.Train
local Vehicle = _G.cs2.Vehicle

local ALL_TRAINS_FILTER = {}
local strace = stlib.strace
local WARN = stlib.WARN

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
	data.stride =
		math.ceil(cs2.PERF_TRAIN_GROUP_MONITOR_WORKLOAD * mod_settings.work_factor)
	data.index = 1
	data.seen_groups = {}
	if game and game.train_manager then
		data.trains = game.train_manager.get_trains(ALL_TRAINS_FILTER)
		data.train_ids = tlib.t_map_a(Vehicle.all(), function(veh)
			if veh.type == "train" then return veh.id end
		end)
		data.state = "enum_luatrains"
	end
end

---@param luatrain LuaTrain
---@param data Cybersyn.Internal.TrainMonitorTaskData
local function monitor_enum_luatrain(luatrain, data)
	if (not luatrain) or not luatrain.valid then return end
	local group_name = luatrain.group
	local vehicle = Train.get_from_luatrain_id(luatrain.id)

	-- If train has no group, remove it if we know about it
	if not group_name then
		if vehicle then
			strace(
				stlib.DEBUG,
				"Destroying vehicle for not being in a train group",
				vehicle
			)
			vehicle:destroy()
		end
		return
	end

	data.seen_groups[group_name] = true
	local group = cs2.get_train_group(group_name)
	if group then
		if vehicle then
			if vehicle.group == group_name then
				-- Train is in the right group, nothing to do.
				return
			else
				-- Train is in a group, but not the one we expect. Remove it from the old group
				cs2.remove_train_from_group(vehicle, vehicle.group)
			end
		end
	else
		-- Group is not a known cybersyn group...
		if cs2.is_cybersyn_train_group_name(group_name) then
			cs2.create_train_group(group_name)
		else
			-- Train is in a non-cybersyn group. If we know about it, remove it.
			if vehicle then
				strace(
					stlib.DEBUG,
					"Destroying vehicle for not being in a CS group",
					vehicle
				)
				vehicle:destroy()
			end
			return
		end
	end

	-- If we reach here, we need to add the train to the game if it doesnt
	-- exist, then add it to the designated group.
	if not vehicle then vehicle = Train.new(luatrain) end
	if not vehicle then
		-- Strange situation; vehicle already exists?
		-- strace(WARN, "message", "couldn't create train for luatrain", luatrain)
		return
	end
	cs2.add_train_to_group(vehicle, group_name)
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
	local train = Vehicle.get(vehicle_id, true)
	if train and (not train:is_valid()) then
		strace(
			stlib.INFO,
			"message",
			"enum_cstrain: destroying train for being invalid",
			train
		)
		train:destroy()
	end
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
	end
end

-- TODO: use threads api better here

cs2.threads_api.schedule_thread("train_group_monitor", train_group_monitor, 1)
