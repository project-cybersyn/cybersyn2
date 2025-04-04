local tlib = require("__cybersyn2__.lib.table")
local types = require("__cybersyn2__.lib.types")
local ContainerType = types.ContainerType
local PrimitiveType = types.PrimitiveType
local combinator_api = _G.cs2.combinator_api
local stop_api = _G.cs2.stop_api
local inventory_api = _G.cs2.inventory_api
local map = tlib.map

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
		res = map(
			arg.ids,
			function(id) return combinator_api.get_combinator(id) end
		)
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
		res = map(arg.ids, function(id) return stop_api.get_stop(id) end)
	elseif arg.unit_numbers then
		res = map(
			arg.unit_numbers,
			function(unit_number)
				return stop_api.get_stop_from_unit_number(unit_number)
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
		res = map(arg.ids, function(id) return inventory_api.get_inventory(id) end)
	end
	return { data = res or {}, type = inv_list_datatype }
end
