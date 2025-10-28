--------------------------------------------------------------------------------
-- Train lifecycle.
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local stlib = require("lib.core.strace")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings
local Train = _G.cs2.Train
local Vehicle = _G.cs2.Vehicle
local TrainStop = _G.cs2.TrainStop

local ALL_TRAINS_FILTER = {}
local strace = stlib.strace
local WARN = stlib.WARN
local INF = math.huge

--------------------------------------------------------------------------------
-- Train group monitor background thread
--------------------------------------------------------------------------------

---@class (exact) Cybersyn.Internal.TrainMonitor: StatefulThread
---@field state "init"|"enum_luatrains"|"enum_cstrains" State of the task.
---@field trains LuaTrain[] Extant luatrains at beginning of sweep.
---@field seen_groups table<string, true> Cybersyn groups seen by sweep.
---@field seen_layouts IdSet Cybersyn train layouts seen by sweep.
---@field train_ids Id[] Extant Cybersyn train vehicle IDs at beginning of sweep.
local TrainMonitor = class("TrainMonitor", cs2.StatefulThread)

function TrainMonitor:new()
	local thread = cs2.StatefulThread.new(self) --[[@as Cybersyn.Internal.TrainMonitor]]
	thread.friendly_name = "train_monitor"
	thread.workload = 20
	thread:set_state("init")
	thread:wake()
	return thread
end

function TrainMonitor:init()
	if game and game.train_manager then self:set_state("enum_luatrains") end
end

function TrainMonitor:enter_enum_luatrains()
	self.seen_groups = {}
	self:begin_async_loop(
		game.train_manager.get_trains(ALL_TRAINS_FILTER),
		math.ceil(cs2.PERF_TRAIN_GROUP_MONITOR_WORKLOAD * mod_settings.work_factor)
	)
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
	self:step_async_loop(
		self.enum_luatrain,
		function(thr) thr:set_state("enum_cstrains") end
	)
end

function TrainMonitor:enter_enum_cstrains()
	self.seen_layouts = {}
	self:begin_async_loop(
		tlib.t_map_a(Vehicle.all(), function(veh)
			if veh.type == "train" then return veh.id end
		end),
		math.ceil(cs2.PERF_TRAIN_GROUP_MONITOR_WORKLOAD * mod_settings.work_factor)
	)
	for _, view in pairs(storage.views) do
		view:enter_vehicles()
	end
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
		return
	end

	---@cast train Cybersyn.Train

	local layout_id = train.layout_id
	if not layout_id then
		-- Train has no layout, nothing to do.
		strace(stlib.WARN, "message", "enum_cstrain: train had no layout", train)
		return
	end

	self.seen_layouts[layout_id] = true

	-- View vehicle visitors
	for _, view in pairs(storage.views) do
		view:enter_vehicle(train)
		view:exit_vehicle(train)
	end
end

function TrainMonitor:enum_cstrains()
	self:step_async_loop(
		self.enum_cstrain,
		function(thr) thr:set_state("init") end
	)
end

function TrainMonitor:exit_enum_cstrains()
	-- Update data for known train layouts.
	local layouts_deleted = false
	for layout_id, train_layout in pairs(storage.train_layouts) do
		if not self.seen_layouts[layout_id] then
			-- Layout is no longer in use, delete it.
			strace(
				stlib.INFO,
				"message",
				"Train layout no longer in use",
				train_layout
			)
			train_layout.no_trains = true
			layouts_deleted = true
		else
			train_layout.no_trains = nil
		end
	end

	if layouts_deleted then cs2.raise_train_layouts_destroyed() end

	for _, view in pairs(storage.views) do
		view:exit_vehicles()
	end

	-- Cleanup
	self.seen_layouts = nil
end

-- Start thread on startup.
events.bind("on_startup", function() TrainMonitor:new() end)

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
		---@diagnostic disable-next-line: param-type-mismatch
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
		---@diagnostic disable-next-line: param-type-mismatch
		cs2.raise_train_departed(luatrain, cstrain, stop)
	end
end)

-- TODO: if a train arrives at a stop, and it's a stop given by a non
-- temp schedule entry, assume it is the depot and wake the interrupted
-- delivery.
