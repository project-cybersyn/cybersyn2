local types = require("lib.types")
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
	["combinators"] = {
		name = "combinators",
		args = {
			ids = {
				false,
				ContainerType.list,
				PrimitiveType.UnitNumber,
			},
		},
		result_type = {
			true,
			ContainerType.list,
			PrimitiveType["Cybersyn.Combinator"],
		},
	},
	["stops"] = {
		name = "stops",
		args = {
			ids = {
				false,
				ContainerType.list,
				PrimitiveType.Id,
			},
			unit_numbers = {
				false,
				ContainerType.list,
				PrimitiveType.UnitNumber,
			},
		},
		result_type = {
			true,
			ContainerType.list,
			PrimitiveType["Cybersyn.TrainStop"],
		},
	},
	["inventories"] = {
		name = "inventories",
		args = {
			ids = {
				false,
				ContainerType.list,
				PrimitiveType.Id,
			},
		},
		result_type = {
			true,
			ContainerType.list,
			PrimitiveType["Cybersyn.Inventory"],
		},
	},
	["vehicles"] = {
		name = "vehicles",
		args = {
			ids = {
				false,
				ContainerType.list,
				PrimitiveType.Id,
			},
			luatrain_ids = {
				false,
				ContainerType.list,
				PrimitiveType.Id,
			},
		},
		result_type = {
			true,
			ContainerType.list,
			PrimitiveType["Cybersyn.Vehicle"],
		},
	},
	["topologies"] = {
		name = "topologies",
		args = {
			ids = {
				false,
				ContainerType.list,
				PrimitiveType.Id,
			},
			surface_index = {
				false,
				ContainerType.list,
				PrimitiveType.Id,
			},
		},
		result_type = {
			true,
			ContainerType.list,
			PrimitiveType["Cybersyn.Topology"],
		},
	},
}

---Machine-readable definitions of enums used in Cybersyn queries. If a
---new query uses an enum in its params or result, it must be added here.
---@type table<string, table<string, string|number>>
local enum_defs = {}

---@type Cybersyn.Query.Queries.Result
local query_query_result = {
	data = query_defs,
	type = {
		true,
		ContainerType.map,
		PrimitiveType.string,
		PrimitiveType["Cybersyn.QueryDef"],
	},
}

---@param arg Cybersyn.Query.Queries.Input
---@return Cybersyn.Query.Queries.Result
function _G.cs2.query_handlers.queries(arg) return query_query_result end
