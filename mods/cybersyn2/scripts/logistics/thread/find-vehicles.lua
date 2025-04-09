--------------------------------------------------------------------------------
-- `find_vehicles` loop step
-- Finds all free vehicles in the active topology and caches them.
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

---@param train Cybersyn.Train
function LogisticsThread:check_train(train)
	if train:is_available() then
		if train.item_slot_capacity > 0 then self.avail_trains[train.id] = train end
		if train.fluid_capacity > 0 then self.avail_trains[train.id] = train end
	end
end

function LogisticsThread:check_vehicle(veh)
	if veh.type == "train" then self:check_train(veh) end
end

function LogisticsThread:enter_find_vehicles()
	local top_id = self.current_topology
	self.all_vehicles = tlib.t_map_a(storage.vehicles, function(veh)
		if veh.topology_id == top_id then return veh end
	end)
	self.avail_trains = {}
	self.stride =
		math.ceil(mod_settings.work_factor * cs2.PERF_FIND_VEHICLES_WORKLOAD)
	self.index = 1
	self.iteration = 1
end

function LogisticsThread:find_vehicles()
	self:async_loop(
		self.all_vehicles,
		self.check_vehicle,
		function(x) x:set_state("route") end
	)
end
