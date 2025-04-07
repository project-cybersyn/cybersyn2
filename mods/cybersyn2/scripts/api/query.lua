local log = require("__cybersyn2__.lib.logging")
local strace_lib = require("__cybersyn2__.lib.strace")
local query_handlers = _G.cs2.query_handlers
local types = require("__cybersyn2__.lib.types")
local ContainerType = types.ContainerType
local PrimitiveType = types.PrimitiveType

local strace = strace_lib.strace
local TRACE = strace_lib.TRACE

---Execute a query against Cybersyn's public state.
---@param query Cybersyn.QueryInput Query type and arguments.
---@return Cybersyn.QueryResult result The result of executing the given query.
function _G.cs2.remote_api.query(query)
	strace(TRACE, "cs2", "query_exec", "message", query)
	local handler = query_handlers[query.type]
	if not handler then
		log.error("Invalid query (bad type)", query)
		return {
			type = { false, ContainerType.value, PrimitiveType.Nil },
			data = nil,
		}
	end
	return handler(query)
end
