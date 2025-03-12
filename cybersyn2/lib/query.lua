-- Types and reusable code relating to Cybersyn queries

if ... ~= "__cybersyn__.lib.query" then
	return require("__cybersyn__.lib.query")
end

---@enum Cybersyn.Query.QueryType
local query_type = {
	-- Query that lists all available queries.
	["query_type"] = "query_type",
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
---@field container_type Cybersyn.Query.ContainerType

local lib = {}

return lib
