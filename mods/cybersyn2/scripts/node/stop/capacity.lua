-- Train stop allowed-capacity evaluation.

local cs2 = _G.cs2
local events = require("lib.core.event")
local tlib = require("lib.core.table")

local EMPTY = tlib.EMPTY_STRICT
local INF = math.huge
local NINF = -math.huge

-- Find a train shaped like the given parameters, but distinct from the given id.
local function find_similar_train(
	id,
	topology_id,
	layout_id,
	item_slot_capacity,
	fluid_capacity
)
	for _, train in pairs(storage.vehicles) do
		if train.type == "train" then
			---@cast train Cybersyn.Train
			if
				train.id ~= id
				and train.topology_id == topology_id
				and train.layout_id == layout_id
				and train.item_slot_capacity == item_slot_capacity
				and train.fluid_capacity == fluid_capacity
			then
				return train
			end
		end
	end
	return nil
end

---@class Cybersyn.Internal.AllowListCapacityCache
---@field public allowed_min_item_slot_capacity int|nil
---@field public allowed_max_item_slot_capacity int|nil
---@field public allowed_min_fluid_capacity int|nil
---@field public allowed_max_fluid_capacity int|nil

---@param stop Cybersyn.TrainStop
---@param cache? Cybersyn.Internal.AllowListCapacityCache
local function evaluate_capacity_for_stop(stop, cache)
	local cached = (cache or EMPTY)[stop.allowed_layouts_key or "IMPOSSIBLE"]
	if cached then
		stop.allowed_min_item_slot_capacity = cached.allowed_min_item_slot_capacity
		stop.allowed_max_item_slot_capacity = cached.allowed_max_item_slot_capacity
		stop.allowed_min_fluid_capacity = cached.allowed_min_fluid_capacity
		stop.allowed_max_fluid_capacity = cached.allowed_max_fluid_capacity
		return
	end

	local min_item_slots, min_fluids = nil, nil
	local max_item_slots, max_fluids = nil, nil

	for _, veh in pairs(storage.vehicles) do
		if veh.type == "train" then
			---@cast veh Cybersyn.Train
			if
				veh.topology_id == stop.topology_id
				and veh:is_valid()
				and stop:accepts_layout(veh.layout_id)
			then
				local fluid_cap = veh.fluid_capacity
				local item_cap = veh.item_slot_capacity
				if
					fluid_cap
					and (fluid_cap > 0)
					and (fluid_cap < (min_fluids or INF))
				then
					min_fluids = fluid_cap
				end
				if
					fluid_cap
					and (fluid_cap > 0)
					and (fluid_cap > (max_fluids or NINF))
				then
					max_fluids = fluid_cap
				end
				if
					item_cap
					and (item_cap > 0)
					and (item_cap < (min_item_slots or INF))
				then
					min_item_slots = item_cap
				end
				if
					item_cap
					and (item_cap > 0)
					and (item_cap > (max_item_slots or NINF))
				then
					max_item_slots = item_cap
				end
			end
		end
	end

	if cache and stop.allowed_layouts_key then
		cache[stop.allowed_layouts_key] = {
			allowed_min_item_slot_capacity = min_item_slots,
			allowed_max_item_slot_capacity = max_item_slots,
			allowed_min_fluid_capacity = min_fluids,
			allowed_max_fluid_capacity = max_fluids,
		}
	end
	stop.allowed_min_item_slot_capacity = min_item_slots
	stop.allowed_max_item_slot_capacity = max_item_slots
	stop.allowed_min_fluid_capacity = min_fluids
	stop.allowed_max_fluid_capacity = max_fluids
end

---@param cache Cybersyn.Internal.AllowListCapacityCache
local function evaluate_capacity_for_layout(topology_id, layout_id, cache)
	for _, stop in pairs(storage.nodes) do
		if stop.type == "stop" then
			---@cast stop Cybersyn.TrainStop
			if
				stop.topology_id == topology_id
				and stop:accepts_layout(layout_id)
				and stop:is_valid()
			then
				evaluate_capacity_for_stop(stop, cache)
			end
		end
	end
end

local function generate_cache_for_stops_in_topology(topology_id)
	local cache = {}
	for _, stop in pairs(storage.nodes) do
		if
			stop.type == "stop"
			---@cast stop Cybersyn.TrainStop

			and stop.allowed_layouts_key
		then
			cache[stop.allowed_layouts_key] = stop
		end
	end
	return cache
end

events.bind(
	"cs2.vehicle_created",
	---@param vehicle Cybersyn.Vehicle
	function(vehicle)
		if vehicle.type ~= "train" or (not vehicle:is_valid()) then return end
		---@cast vehicle Cybersyn.Train
		if
			not find_similar_train(
				vehicle.id,
				vehicle.topology_id,
				vehicle.layout_id,
				vehicle.item_slot_capacity,
				vehicle.fluid_capacity
			)
		then
			evaluate_capacity_for_layout(vehicle.topology_id, vehicle.layout_id, {})
		end
	end
)

events.bind("cs2.vehicle_destroyed", function(vehicle)
	if vehicle.type ~= "train" then return end
	---@cast vehicle Cybersyn.Train
	if
		not find_similar_train(
			vehicle.id,
			vehicle.topology_id,
			vehicle.layout_id,
			vehicle.item_slot_capacity,
			vehicle.fluid_capacity
		)
	then
		evaluate_capacity_for_layout(vehicle.topology_id, vehicle.layout_id, {})
	end
end)

events.bind("cs2.train_capacity_changed", function(train, cache)
	cache[train.topology_id] = cache[train.topology_id] or {}
	evaluate_capacity_for_layout(
		train.topology_id,
		train.layout_id,
		cache[train.topology_id]
	)
end)

events.bind(
	"cs2.stop_allow_list_changed",
	---@param stop Cybersyn.TrainStop
	function(stop) evaluate_capacity_for_stop(stop) end
)

events.bind(
	"cs2.node_topology_changed",
	---@param stop Cybersyn.Node
	function(stop)
		if stop.type ~= "stop" then return end
		---@cast stop Cybersyn.TrainStop
		evaluate_capacity_for_stop(stop)
	end
)

events.bind(
	"cs2.vehicle_topology_changed",
	---@param vehicle Cybersyn.Vehicle
	function(vehicle, previous_topology_id)
		if vehicle.type ~= "train" or (not vehicle:is_valid()) then return end
		---@cast vehicle Cybersyn.Train
		if
			not find_similar_train(
				vehicle.id,
				vehicle.topology_id,
				vehicle.layout_id,
				vehicle.item_slot_capacity,
				vehicle.fluid_capacity
			)
		then
			evaluate_capacity_for_layout(vehicle.topology_id, vehicle.layout_id, {})
		end

		if previous_topology_id then
			if
				not find_similar_train(
					vehicle.id,
					previous_topology_id,
					vehicle.layout_id,
					vehicle.item_slot_capacity,
					vehicle.fluid_capacity
				)
			then
				evaluate_capacity_for_layout(
					previous_topology_id,
					vehicle.layout_id,
					{}
				)
			end
		end
	end
)
