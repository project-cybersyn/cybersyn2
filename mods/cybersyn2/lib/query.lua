-- Types and reusable code for the public Cybersyn query interface.
-- TODO: this whole file is a WIP.

if ... ~= "__cybersyn2__.lib.query" then
	return require("__cybersyn2__.lib.query")
end

require("__cybersyn2__.lib.types")

local lib = {}

---@enum Cybersyn.QueryType
local QueryType = {
	["queries"] = "queries",
	["enums"] = "enums",
}
lib.QueryType = QueryType

---@class Cybersyn.QueryInput
---@field public type Cybersyn.QueryType Type of query
---@field public args table? Arguments of the query

---@class Cybersyn.QueryResult
---@field public data any Result data

---------- "Queries" query

---@class Cybersyn.Query.Queries.Input: Cybersyn.QueryInput
---@field public type "queries"
---@field public args nil

---@class Cybersyn.Query.Queries.Result: Cybersyn.QueryResult
---@field public data table<string,Cybersyn.QueryDef>

---@class Cybersyn.QueryDef
---@field public name string Name of the query
---@field public args table<string,Cybersyn.DataType> Arguments of the query
---@field public result_type Cybersyn.DataType Type of the `data` field in the result object.

---------- "Enums" query

---@class Cybersyn.Query.Enums.Input: Cybersyn.QueryInput
---@field public type "enums"
---@field public args nil

---@class Cybersyn.Query.Enums.Result: Cybersyn.QueryResult
---@field public data table<string,table<string,string|number>> Map from names of enum types to maps of enum keys to enum values for each type.

return lib
