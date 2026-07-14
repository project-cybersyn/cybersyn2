local class = require("lib.core.class").class
local cmt = require("lib.core.cmt")
local tasks = require("scripts.tasks.base")
local strace = require("lib.core.strace")
local tlib = require("lib.core.table")
local events = require("lib.core.event")

local add_workload = tasks.add_workload
local pairs = pairs
local ALL_TRAINS_FILTER = {}

--------------------------------------------------------------------------------
-- Train group monitor background thread
--------------------------------------------------------------------------------

---@class (exact) Cybersyn.Internal.TrainMonitor: StatefulTask
---@field state "init"|"enum_luatrains"|"enum_cstrains" State of the task.
---@field trains LuaTrain[] Extant luatrains at beginning of sweep.
---@field seen_groups table<string, true> Cybersyn groups seen by sweep.
---@field seen_layouts IdSet Cybersyn train layouts seen by sweep.
---@field train_ids Id[] Extant Cybersyn train vehicle IDs at beginning of sweep.
---@field last_tick int64 Last tick the monitor completed a sweep.
---@field loop_length_era Core.EraCounter Era of loop length.
local TrainMonitor = class("TrainMonitor", cs2.StatefulTask)

function TrainMonitor:new()
	local thread = cs2.StatefulTask.new(self) --[[@as Cybersyn.Internal.TrainMonitor]]
	thread._cmt_name = "TrainMonitor"
	-- TODO: set caps
	thread._cmt_work_cap = 20
	thread.last_tick = game and game.tick or 0
	thread.loop_length_era = cs2.EraCounter.new()
	thread:set_state("init")
	cmt.wake(thread)
	return thread
end

function TrainMonitor:init()
	if game and game.train_manager then self:set_state("enum_luatrains") end
end

function TrainMonitor:enter_enum_luatrains()
	self.seen_groups = {}
	self:begin_async_loop(game.train_manager.get_trains(ALL_TRAINS_FILTER), 1)
end

---@param luatrain LuaTrain
function TrainMonitor:enum_luatrain(luatrain)
	if (not luatrain) or not luatrain.valid then return end
	local group_name = luatrain.group
	local vehicle = cs2.get_train_from_luatrain_id(luatrain.id)
	add_workload(self.workload_counter, 1)

	-- If train has no group, remove it if we know about it
	if not group_name then
		-- Don't destroy volatile trains.
		if vehicle and not vehicle.volatile then
			strace.debug("Destroying vehicle for not being in a train group", vehicle)
			vehicle:destroy()
		end
		return
	end

	self.seen_groups[group_name] = true

	-- Don't consider volatile vehicles further.
	if vehicle and vehicle.volatile then return end

	local group = cs2.get_train_group(group_name)
	add_workload(self.workload_counter, 1)
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
				strace.debug("Destroying vehicle for not being in a CS group", vehicle)
				vehicle:destroy()
			end
			return
		end
	end

	-- If we reach here, we need to add the train to the game if it doesnt
	-- exist, then add it to the designated group.
	if not vehicle then vehicle = cs2.Train.new(luatrain) end
	if not vehicle then
		-- Strange situation; vehicle already exists?
		-- strace(WARN, "message", "couldn't create train for luatrain", luatrain)
		return
	end
	cs2.add_train_to_group(vehicle, group_name)
	add_workload(self.workload_counter, 2)
end

function TrainMonitor:enum_luatrains()
	self:step_async_loop(
		self.enum_luatrain,
		function(thr) thr:set_state("enum_cstrains") end
	)
end

function TrainMonitor:enter_enum_cstrains()
	self.seen_layouts = {}
	local cstrains = tlib.t_map_a(cs2.get_all_vehicles(), function(veh)
		if veh.type == "train" then return veh.id end
	end)
	self:begin_async_loop(cstrains, 1)
	for _, view in pairs(storage.views) do
		view:enter_vehicles(self.workload_counter)
	end
	add_workload(self.workload_counter, 1 + #cstrains)
end

function TrainMonitor:enum_cstrain(vehicle_id)
	if not vehicle_id then return end
	local train = cs2.get_vehicle(vehicle_id, true)
	if not train then
		-- Vehicle got async deleted somehow...
		return
	end
	---@cast train Cybersyn.Train

	add_workload(self.workload_counter, 2)

	if (not train.volatile) and (not train:is_valid()) then
		strace.info(
			"message",
			"enum_cstrain: destroying train for being invalid",
			train
		)
		train:destroy()
		return
	end

	-- Flag layout as seen
	local layout_id = train.layout_id
	if not layout_id then
		-- Train has no layout, nothing to do.
		strace.warn("message", "enum_cstrain: train had no layout", train)
		return
	end
	self.seen_layouts[layout_id] = true

	-- Apply group topo settings
	local group = cs2.get_train_group(train.group)
	if group then
		train:set_topology(group.topology_id)
	else
		strace.warn("enum_cstrain: train had no group", train, train.group)
	end

	-- View vehicle visitors
	for _, view in pairs(storage.views) do
		view:enter_vehicle(self.workload_counter, train)
		view:exit_vehicle(self.workload_counter, train)
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
		if self.seen_layouts[layout_id] or train_layout.recent then
			-- Layout is still in use, nothing to do.
			if train_layout.no_trains then
				strace.info("message", "Train layout now in use again", train_layout)
				train_layout.no_trains = nil
				cs2.raise_train_layout_created(train_layout)
			end
		else
			if not train_layout.no_trains then
				-- Layout is no longer in use.
				strace.info("message", "Train layout no longer in use", train_layout)
				train_layout.no_trains = true
				layouts_deleted = true
			end
		end
		train_layout.recent = nil
	end

	if layouts_deleted then events.raise("cs2.train_layouts_destroyed") end

	for _, view in pairs(storage.views) do
		view:exit_vehicles(self.workload_counter)
	end

	-- Cleanup
	self.seen_layouts = nil

	add_workload(self.workload_counter, 5)
end

-- Start thread on startup.
events.bind("on_startup", function() TrainMonitor:new() end)
