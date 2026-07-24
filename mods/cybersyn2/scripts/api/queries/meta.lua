local types = require("lib.types")
local ContainerType = types.ContainerType
local PrimitiveType = types.PrimitiveType
local cs2 = _G.cs2

local lib = {}

---@enum Cybersyn.QueryType
local QueryType = {
	["queries"] = "queries",
	["enums"] = "enums",
	["combinators"] = "combinators",
	["stops"] = "stops",
	["vehicles"] = "vehicles",
	["inventories"] = "inventories",
	["topologies"] = "topologies",
}
lib.QueryType = QueryType

---@class Cybersyn.QueryInput
---@field public type Cybersyn.QueryType Type of query

---@class Cybersyn.QueryResult
---@field public type Cybersyn.DataType Type of the result
---@field public data any Result data

---------- "queries"

---@class Cybersyn.Query.Queries.Input: Cybersyn.QueryInput
---@field public type "queries"

---@class Cybersyn.Query.Queries.Result: Cybersyn.QueryResult
---@field public data table<string,Cybersyn.QueryDef>

---@class Cybersyn.QueryDef
---@field public name string Name of the query
---@field public args table<string,Cybersyn.DataType> Arguments of the query
---@field public result_type Cybersyn.DataType Type of the `data` field in the result object.

---------- "enums"

---@class Cybersyn.Query.Enums.Input: Cybersyn.QueryInput
---@field public type "enums"

---@class Cybersyn.Query.Enums.Result: Cybersyn.QueryResult
---@field public data table<string,table<string,string|number>> Map from names of enum types to maps of enum keys to enum values for each type.

----------- "combinators"

---@class Cybersyn.Query.Combinators.Input: Cybersyn.QueryInput
---@field public type "combinators"
---@field public ids UnitNumber[]? List of IDs to query.

---@class Cybersyn.Query.Combinators.Result: Cybersyn.QueryResult
---@field public data Cybersyn.Combinator[]

----------- "stops"

---@class Cybersyn.Query.Stops.Input: Cybersyn.QueryInput
---@field public type "stops"
---@field public ids Id[]? List of IDs to query.
---@field public unit_numbers UnitNumber[]? Query by `train-stop` unit number.
---@field public all boolean? Whether to query all stops. Ignored if `ids` or `unit_numbers` is provided.

---@class Cybersyn.Query.Stops.Result: Cybersyn.QueryResult
---@field public data Cybersyn.TrainStop[]

----------- "stop"

---@class Cybersyn.Query.Stop.Input: Cybersyn.QueryInput
---@field public type "stop"
---@field public unit_number UnitNumber? Query by `train-stop` unit number.

---@class Cybersyn.Query.Stop.Result: Cybersyn.QueryResult
---@field public data Cybersyn.TrainStop?

----------- "inventories"

---@class Cybersyn.Query.Inventories.Input: Cybersyn.QueryInput
---@field public type "inventories"
---@field public ids Id[]? List of IDs to query.

---@class Cybersyn.Query.Inventories.Result: Cybersyn.QueryResult
---@field public data Cybersyn.Inventory[]

----------- "vehicles"

---@class Cybersyn.Query.Vehicles.Input: Cybersyn.QueryInput
---@field public type "vehicles"
---@field public ids Id[]? List of veh IDs to query.
---@field public luatrain_ids Id[]? List of luatrain IDs to query

---@class Cybersyn.Query.Vehicles.Result: Cybersyn.QueryResult
---@field public data Cybersyn.Vehicle[]

----------- "topologies"

---@class Cybersyn.Query.Topologies.Input: Cybersyn.QueryInput
---@field public type "topologies"
---@field public ids Id[]? List of topology IDs to query.
---@field public surface_index Id[]? List of surface indices to query.

---@class Cybersyn.Query.Topologies.Result: Cybersyn.QueryResult
---@field public data Cybersyn.Topology[]

----------- "groups"

---@class Cybersyn.Query.Groups.Input: Cybersyn.QueryInput
---@field public type "groups"
---@field public all boolean? Whether to query all groups.

---@class Cybersyn.Query.Groups.Result: Cybersyn.QueryResult
---@field public data string[] List of train group names.

----------- "deliveries"

---@class Cybersyn.Query.Deliveries.Input: Cybersyn.QueryInput
---@field public type "deliveries"
---@field public ids Id[]? List of delivery IDs to query.
---@field public vehicle_id Id? Query by vehicle ID.
---@field public node_id Id? Query by node ID.

---@class Cybersyn.Query.Deliveries.Result: Cybersyn.QueryResult
---@field public data Cybersyn.Delivery[]

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
function cs2.query_handlers.queries(arg) return query_query_result end

return lib
