local tlib = require("__cybersyn2__.lib.table")

local equipment_types_set = {
	inserter = true,
	pump = true,
	["loader-1x1"] = true,
	loader = true,
}
local equipment_types = tlib.t_map_a(equipment_types_set, function(_, k) return k end)
local equipment_names_set = {}
local equipment_names = tlib.t_map_a(equipment_names_set, function(_, k) return k end)

---Get a list of prototype types of equipment that might be used for loading and unloading at a stop.
---@return string[]
function stop_api.get_equipment_types()
	return equipment_types
end

---Check if a string is a type of a piece of equipment that might be used for loading and unloading at a stop.
---@param type string?
function stop_api.is_equipment_type(type)
	return equipment_types_set[type or ""] or false
end

---Get a list of prototype names of equipment that might be used for loading and unloading at a stop.
---@return string[]
function stop_api.get_equipment_names()
	return equipment_names
end

---Check if a string is the name of a piece of equipment that might be used for loading and unloading at a stop.
---@param name string?
function stop_api.is_equipment_name(name)
	return equipment_names_set[name or ""] or false
end
