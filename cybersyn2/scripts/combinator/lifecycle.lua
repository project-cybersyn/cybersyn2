-- Lifecycle management for combinators.
-- Combinator state is only created/destroyed in this module.
-- We also manage the physical storage of combinator settings here.

local log = require("__cybersyn2__.lib.logging")

---@param combinator_entity LuaEntity A *valid* reference to a non-ghost combinator.
---@return Cybersyn.Combinator.Internal
local function create_combinator_state(combinator_entity)
	---@type Cybersyn.Storage
	local data = storage
	local combinator_id = combinator_entity.unit_number
	if not combinator_id then
		-- Should be impossible. Have to crash here as this function cant return nil.
		error("Combinator entity has no unit number.")
	end
	data.combinators[combinator_id] = {
		id = combinator_id,
		entity = combinator_entity,
	} --[[@as Cybersyn.Combinator.Internal]]

	return data.combinators[combinator_id]
end

---@param combinator_id UnitNumber
---@return boolean `true` if the combinator was removed, `false` if it was not found.
local function destroy_combinator_state(combinator_id)
	---@type Cybersyn.Storage
	local data = storage
	if data.combinators[combinator_id] then
		data.combinators[combinator_id] = nil
		return true
	end
	return false
end

on_built_combinator(function(combinator_entity)
	local comb_id = combinator_entity.unit_number --[[@as UnitNumber]]
	local comb = combinator_api.get_combinator(comb_id, true)
	if comb then
		-- Should be impossible
		log.error("Duplicate combinator unit number, should be impossible.", comb_id)
		return
	end
	comb = create_combinator_state(combinator_entity)

	-- TODO: revive/create hidden companion entities

	raise_combinator_created(comb)
end)

on_broken_combinator(function(combinator_entity)
	local comb = combinator_api.get_combinator(combinator_entity.unit_number, true)
	if not comb then return end
	comb.is_being_destroyed = true

	-- Disassociate this combinator from any node it may be connected to
	local node = node_api.get_node(comb.node_id, true)
	if node then node_api.disassociate_combinator(node, comb.id) end
	comb.node_id = nil

	raise_combinator_destroyed(comb)

	-- TODO: destroy hidden companion entities

	destroy_combinator_state(comb.id)
end)
