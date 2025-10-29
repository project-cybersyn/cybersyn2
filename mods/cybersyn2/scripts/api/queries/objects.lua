local tlib = require("lib.core.table")
local types = require("lib.types")
local ContainerType = types.ContainerType
local PrimitiveType = types.PrimitiveType
local Inventory = _G.cs2.Inventory

local map = tlib.map
local Combinator = _G.cs2.Combinator
local Vehicle = _G.cs2.Vehicle
local Train = _G.cs2.Train
local TrainStop = _G.cs2.TrainStop
local Topology = _G.cs2.Topology
local Delivery = _G.cs2.Delivery

local comb_list_datatype = {
	true,
	ContainerType.list,
	PrimitiveType["Cybersyn.Combinator"],
}

---@param arg Cybersyn.Query.Combinators.Input
---@return Cybersyn.Query.Combinators.Result
function _G.cs2.query_handlers.combinators(arg)
	---@type Cybersyn.Combinator[]
	local res = nil
	if arg.ids then
		res = map(arg.ids, function(id) return cs2.get_combinator(id) end)
	end
	return { data = res or {}, type = comb_list_datatype }
end

local stop_list_datatype = {
	true,
	ContainerType.list,
	PrimitiveType["Cybersyn.TrainStop"],
}

---@param arg Cybersyn.Query.Stops.Input
---@return Cybersyn.Query.Stops.Result
function _G.cs2.query_handlers.stops(arg)
	local res = nil
	if arg.ids then
		res = map(arg.ids, function(id) return TrainStop.get(id) end)
	elseif arg.unit_numbers then
		res = map(
			arg.unit_numbers,
			function(unit_number)
				return TrainStop.get_stop_from_unit_number(unit_number)
			end
		)
	end
	return { data = res, type = stop_list_datatype }
end

local inv_list_datatype = {
	true,
	ContainerType.list,
	PrimitiveType["Cybersyn.Combinator"],
}

---@param arg Cybersyn.Query.Inventories.Input
---@return Cybersyn.Query.Inventories.Result
function _G.cs2.query_handlers.inventories(arg)
	---@type Cybersyn.Inventory[]
	local res = nil
	if arg.ids then
		res = map(arg.ids, function(id) return Inventory.get(id) end)
	end
	return { data = res or {}, type = inv_list_datatype }
end

local veh_list_datatype = {
	true,
	ContainerType.list,
	PrimitiveType["Cybersyn.Vehicle"],
}

---@param arg Cybersyn.Query.Vehicles.Input
---@return Cybersyn.Query.Vehicles.Result
function _G.cs2.query_handlers.vehicles(arg)
	---@type Cybersyn.Vehicle[]
	local res = {}
	if arg.ids then
		local ids = arg.ids --[[@as Id[] ]]
		for i = 1, #ids do
			local veh = Vehicle.get(ids[i])
			if veh then res[#res + 1] = veh end
		end
	end
	if arg.luatrain_ids then
		local ids = arg.luatrain_ids --[[@as Id[] ]]
		for i = 1, #ids do
			local veh = Train.get_from_luatrain_id(ids[i])
			if veh then res[#res + 1] = veh end
		end
	end
	return { data = res or {}, type = veh_list_datatype }
end

local top_list_datatype = {
	true,
	ContainerType.list,
	PrimitiveType["Cybersyn.Topology"],
}

---@param arg Cybersyn.Query.Topologies.Input
---@return Cybersyn.Query.Topologies.Result
function _G.cs2.query_handlers.topologies(arg)
	---@type Cybersyn.Topology[]
	local res = nil
	if arg.ids then
		res = map(arg.ids, function(id) return Topology.get(id) end)
	elseif arg.surface_index then
		res = map(
			arg.surface_index,
			function(surface_index) return Topology.get_train_topology(surface_index) end
		)
	else
		res = tlib.t_map_a(storage.topologies, function(t) return t end)
	end
	return { data = res or {}, type = top_list_datatype }
end

---@param deliveries Cybersyn.Delivery[]
local function format_deliveries(deliveries)
	return map(deliveries, function(d_in)
		local d = tlib.assign({}, d_in) --[[@as Cybersyn.Delivery ]]
		local from_stop = TrainStop.get(d.from_id)
		if from_stop then d.from_entity = from_stop.entity end
		local to_stop = TrainStop.get(d.to_id)
		if to_stop then d.to_entity = to_stop.entity end
		return d
	end)
end

function _G.cs2.query_handlers.deliveries(arg)
	---@type Cybersyn.Delivery[]
	local res = nil
	if arg.ids then
		res =
			format_deliveries(map(arg.ids, function(id) return Delivery.get(id) end))
	elseif arg.vehicle_id then
		local vehicle_id = arg.vehicle_id
		local filtered = tlib.t_map_a(storage.deliveries, function(d)
			if d.vehicle_id == vehicle_id then return d end
		end)
		res = format_deliveries(filtered)
	end
	return { data = res or {} }
end
