--------------------------------------------------------------------------------
-- `find_vehicles` loop step
-- Finds all free vehicles in the active topology and caches them.
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings
local logistics_thread = _G.cs2.logistics_thread

---@param train Cybersyn.Train
---@param data Cybersyn.Internal.LogisticsThreadData
local function check_train(train, data)
	if train:is_available() then
		if train.item_slot_capacity > 0 then
			data.avail_trains[train.id] = train
			data.trains_by_icap[#data.trains_by_icap + 1] = train
		end
		if train.fluid_capacity > 0 then
			data.avail_trains[train.id] = train
			data.trains_by_fcap[#data.trains_by_fcap + 1] = train
		end
	end
end

---@param data Cybersyn.Internal.LogisticsThreadData
local function check_vehicle(veh, data)
	if veh.type == "train" then check_train(veh, data) end
end

--------------------------------------------------------------------------------
-- Loop step lifecycle
--------------------------------------------------------------------------------

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.goto_find_vehicles(data)
	local top_id = data.current_topology
	data.all_vehicles = tlib.t_map_a(storage.vehicles, function(veh)
		if veh.topology_id == top_id then return veh end
	end)
	data.avail_trains = {}
	data.trains_by_fcap = {}
	data.trains_by_icap = {}
	data.stride =
		math.ceil(mod_settings.work_factor * cs2.PERF_FIND_VEHICLES_WORKLOAD)
	data.index = 1
	data.state = "find_vehicles"
end

---@param data Cybersyn.Internal.LogisticsThreadData
local function cleanup_find_vehicles(data)
	table.sort(
		data.trains_by_fcap,
		function(a, b) return a.fluid_capacity < b.fluid_capacity end
	)
	table.sort(
		data.trains_by_icap,
		function(a, b) return a.item_slot_capacity < b.item_slot_capacity end
	)
	logistics_thread.goto_route(data)
end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.find_vehicles(data)
	cs2.logistics_thread.stride_loop(
		data,
		data.all_vehicles,
		check_vehicle,
		function(data2) cleanup_find_vehicles(data2) end
	)
end
