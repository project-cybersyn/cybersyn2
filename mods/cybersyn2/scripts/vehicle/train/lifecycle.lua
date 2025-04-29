--------------------------------------------------------------------------------
-- Train lifecycle.
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local stlib = require("__cybersyn2__.lib.strace")
local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings
local Train = _G.cs2.Train
local Vehicle = _G.cs2.Vehicle
local TrainStop = _G.cs2.TrainStop

local ALL_TRAINS_FILTER = {}
local strace = stlib.strace
local WARN = stlib.WARN

--------------------------------------------------------------------------------
-- Train group monitor background thread
--------------------------------------------------------------------------------

---@class Cybersyn.Internal.TrainMonitor: StatefulThread
---@field state "init"|"enum_luatrains"|"enum_cstrains" State of the task.
---@field trains LuaTrain[] Extant luatrains at beginning of sweep.
---@field seen_groups table<string, true> Cybersyn groups seen by sweep.
---@field train_ids Id[] Extant Cybersyn train vehicle IDs at beginning of sweep.
local TrainMonitor = class("TrainMonitor", cs2.StatefulThread)

function TrainMonitor.new()
	local thread = setmetatable({}, TrainMonitor) --[[@as Cybersyn.Internal.TrainMonitor]]
	thread:set_state("init")
	return thread
end

function TrainMonitor:init()
	if game and game.train_manager then self:set_state("enum_luatrains") end
end

function TrainMonitor:enter_enum_luatrains()
	self.stride =
		math.ceil(cs2.PERF_TRAIN_GROUP_MONITOR_WORKLOAD * mod_settings.work_factor)
	self.index = 1
	self.seen_groups = {}
	self.trains = game.train_manager.get_trains(ALL_TRAINS_FILTER)
end

---@param luatrain LuaTrain
function TrainMonitor:enum_luatrain(luatrain)
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

	self.seen_groups[group_name] = true
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

function TrainMonitor:enum_luatrains()
	self:async_loop(
		self.trains,
		self.enum_luatrain,
		function(thr) thr:set_state("enum_cstrains") end
	)
end

function TrainMonitor:enter_enum_cstrains()
	self.index = 1
	self.trains = nil
	self.train_ids = tlib.t_map_a(Vehicle.all(), function(veh)
		if veh.type == "train" then return veh.id end
	end)
end

function TrainMonitor:enum_cstrain(vehicle_id)
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

function TrainMonitor:enum_cstrains()
	self:async_loop(
		self.train_ids,
		self.enum_cstrain,
		function(thr) thr:set_state("init") end
	)
end

function TrainMonitor:exit_enum_cstrains() self.train_ids = nil end

cs2.schedule_thread(
	"train_group_monitor",
	1,
	function() return TrainMonitor.new() end
)

--------------------------------------------------------------------------------
-- Handle trains arriving/leaving at stops
--------------------------------------------------------------------------------

local WAIT_STATION = defines.train_state.wait_station

cs2.on_luatrain_changed_state(function(event)
	local luatrain = event.train
	local luatrain_state = luatrain.state
	local old_state = event.old_state
	if luatrain_state ~= WAIT_STATION and old_state ~= WAIT_STATION then
		-- Not entering or leaving a station, nothing to do
		return
	end

	-- Augment event with data about which Cybersyn objects are involved.
	local cstrain = Train.get_from_luatrain_id(luatrain.id)

	if luatrain_state == WAIT_STATION then
		-- Train just arrived at station
		local stop_entity = luatrain.station
		local stop = (stop_entity and stop_entity.valid)
				and TrainStop.get_stop_from_unit_number(stop_entity.unit_number)
			or nil
		if cstrain then cstrain.stopped_at = stop_entity end
		cs2.raise_train_arrived(luatrain, cstrain, stop)
	elseif old_state == WAIT_STATION then
		-- Train just left station
		local stop = nil
		if cstrain then
			if cstrain.stopped_at and cstrain.stopped_at.valid then
				stop =
					TrainStop.get_stop_from_unit_number(cstrain.stopped_at.unit_number)
			end
			cstrain.stopped_at = nil
		end
		cs2.raise_train_departed(luatrain, cstrain, stop)
	end
end)

-- TODO: if a train arrives at a stop, and it's a stop given by a non
-- temp schedule entry, assume it is the depot and wake the interrupted
-- delivery.
