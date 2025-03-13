-- Types and reusable code for the public Cybersyn query interface.

if ... ~= "__cybersyn2__.lib.query" then
	return require("__cybersyn2__.lib.query")
end

require("__cybersyn2__.lib.types")

---@enum Cybersyn.Query.QueryType
local query_type = {
	-- Query that lists all available queries.
	["queries"] = "queries",
}

---@enum Cybersyn.Query.ContainerType
local container_type = {
	["value"] = "value",
	["list"] = "list",
	["set"] = "set",
	["map"] = "map",
}

---@class Cybersyn.Query.Result
---@field query_type Cybersyn.Query.QueryType

local lib = {}

return lib
