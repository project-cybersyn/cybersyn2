-- Types and reusable code for the public Cybersyn query interface.

if ... ~= "__cybersyn2__.lib.query" then
	return require("__cybersyn2__.lib.query")
end

require("__cybersyn2__.lib.types")

local lib = {}

---@enum Cybersyn.QueryType
local QueryType = {
	["queries"] = "queries",
	["enums"] = "enums",
	["combinators"] = "combinators",
	["stops"] = "stops",
	["vehicles"] = "vehicles",
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

---@class Cybersyn.Query.Stops.Result: Cybersyn.QueryResult
---@field public data Cybersyn.TrainStop[]

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

---@class Cybersyn.Query.Topologies.Input: Cybersyn.QueryInput
---@field public type "topologies"
---@field public ids Id[]? List of topology IDs to query.
---@field public surface_index Id[]? List of surface indices to query.

---@class Cybersyn.Query.Topologies.Result: Cybersyn.QueryResult
---@field public data Cybersyn.Topology[]

return lib
