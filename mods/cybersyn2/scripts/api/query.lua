---Execute a query against Cybersyn's public state.
---@param query Cybersyn.QueryInput Query type and arguments.
---@return Cybersyn.QueryResult result The result of executing the given query.
function remote_api.query(query)
	return query_handlers[query.type](query)
end
