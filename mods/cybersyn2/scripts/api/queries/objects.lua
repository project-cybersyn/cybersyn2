local tlib = require("__cybersyn2__.lib.table")
local types = require("__cybersyn2__.lib.types")
local ContainerType = types.ContainerType
local PrimitiveType = types.PrimitiveType
local Inventory = _G.cs2.Inventory

local map = tlib.map
local Combinator = _G.cs2.Combinator
local Vehicle = _G.cs2.Vehicle
local Train = _G.cs2.Train
local TrainStop = _G.cs2.TrainStop
local Topology = _G.cs2.Topology

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
		res = map(arg.ids, function(id) return Combinator.get(id) end)
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
