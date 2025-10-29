local cs2 = _G.cs2

---@type table<string, fun(query: Cybersyn.QueryInput): Cybersyn.QueryResult>
_G.cs2.query_handlers = {}

function _G.cs2.remote_api.migrate_tags_callback(tags) return tags end

function _G.cs2.remote_api.initial_tags_callback(entity)
	return cs2.DEFAULT_COMBINATOR_SETTINGS
end
