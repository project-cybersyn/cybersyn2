--------------------------------------------------------------------------------
-- Train lifecycle.
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local stlib = require("lib.core.strace")
local tlib = require("lib.core.table")
local thread_lib = require("lib.core.thread")
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
local add_workload = thread_lib.add_workload

--------------------------------------------------------------------------------
-- Handle trains arriving/leaving at stops
--------------------------------------------------------------------------------

local WAIT_STATION = defines.train_state.wait_station

---@param rail_end LuaRailEnd
---@return Cybersyn.TrainStop?
local function get_stop_from_rail_end(rail_end)
	local rail = rail_end.rail
	local stop_entity = rail.get_rail_segment_stop(rail_end.direction)
	return stop_entity and cs2.get_stop_from_unit_number(stop_entity.unit_number)
end

---@param luatrain LuaTrain
---@return Cybersyn.TrainStop?
local function get_stop_from_luatrain(luatrain)
	local stop = get_stop_from_rail_end(luatrain.front_end)
	if stop then return stop end
	return get_stop_from_rail_end(luatrain.back_end)
end

cs2.on_luatrain_changed_state(function(event)
	local luatrain = event.train
	local luatrain_state = luatrain.state
	local old_state = event.old_state
	if luatrain_state ~= WAIT_STATION and old_state ~= WAIT_STATION then
		-- Not entering or leaving a station, nothing to do
		return
	end

	-- Augment event with data about which Cybersyn objects are involved.
	local cstrain = cs2.get_train_from_luatrain_id(luatrain.id)

	if luatrain_state == WAIT_STATION then
		-- Train arrived either at a station or a coordinate stop.
		-- Check which case we are in and get the stop.
		local stop_entity = luatrain.station
		local valid_stop = stop_entity and stop_entity.valid

		-- Vanilla priority warning
		---@diagnostic disable-next-line: need-check-nil
		if cstrain and valid_stop and stop_entity.train_stop_priority ~= 50 then
			events.raise("cs2.alert.vanilla_priority", stop_entity)
		end

		local stop = valid_stop
				---@diagnostic disable-next-line: need-check-nil
				and cs2.get_stop_from_unit_number(stop_entity.unit_number)
			or nil
		if cstrain then cstrain.stopped_at = stop_entity end

		-- Coordinate stop (no stop_entity)
		if cstrain and not stop_entity then
			-- Raise a pre-arrival event for coordinate stops.
			local pre_stop = get_stop_from_luatrain(luatrain)
			if pre_stop then
				events.raise("cs2.train_pre_arrived", luatrain, cstrain, pre_stop)
			end
		end

		---@diagnostic disable-next-line: param-type-mismatch
		cs2.raise_train_arrived(luatrain, cstrain, stop)
	elseif old_state == WAIT_STATION then
		-- Train just left station
		local stop = nil
		if cstrain then
			if cstrain.stopped_at and cstrain.stopped_at.valid then
				stop = cs2.get_stop_from_unit_number(cstrain.stopped_at.unit_number)
			end
			cstrain.stopped_at = nil
		end
		---@diagnostic disable-next-line: param-type-mismatch
		cs2.raise_train_departed(luatrain, cstrain, stop)
	end
end)

-- TODO: if a train arrives at a stop, and it's a stop given by a non
-- temp schedule entry, assume it is the depot and wake the interrupted
-- delivery. (Actually dont do this because of SE/space elevators)
