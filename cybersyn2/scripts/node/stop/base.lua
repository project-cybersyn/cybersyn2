stop_api = {}

---Find the stop associated to the given rail using the rail cache.
---@param rail_entity LuaEntity A *valid* rail.
---@return Cybersyn.TrainStop? #The stop state, if found. For performance reasons, this state is not checked for validity.
function stop_api.find_stop_from_rail(rail_entity)
	---@type Cybersyn.Storage
	local data = storage
	local stop_id = data.rail_id_to_node_id[rail_entity.unit_number]
	if stop_id then return data.nodes[stop_id] --[[@as Cybersyn.TrainStop?]] end
end
