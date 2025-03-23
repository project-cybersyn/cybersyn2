local types = require("__cybersyn2__.lib.types")
local query_lib = require("__cybersyn2__.lib.query")
local ContainerType = types.ContainerType
local PrimitiveType = types.PrimitiveType

---Machine-readable definitions of all possible Cybersyn queries. New
---queries must be registered here when added.
---@type table<string, Cybersyn.QueryDef>
local query_defs = {
	["queries"] = {
		name = "queries",
		args = {},
		result_type = {
			true,
			ContainerType.map,
			PrimitiveType.string,
			PrimitiveType["Cybersyn.QueryDef"],
		},
	},
	["enums"] = {
		name = "enums",
		args = {},
		result_type = {
			true,
			ContainerType.map,
			PrimitiveType.string,
			PrimitiveType.EnumValues,
		},
	},
}

---Machine-readable definitions of enums used in Cybersyn queries. If a
---new query uses an enum in its params or result, it must be added here.
---@type table<string, table<string, string|number>>
local enum_defs = {}

local query_query_result = { data = query_defs }

---@param arg Cybersyn.Query.Queries.Input
---@return Cybersyn.Query.Queries.Result
function _G.cs2.query_handlers.queries(arg) return query_query_result end
