-- Base types and library code for manipulating Cybersyn combinators.

if not combinator_api then combinator_api = {} end

---Full internal game state of a combinator.
---@class Cybersyn.Combinator.Internal: Cybersyn.Combinator
---@field public output_entity LuaEntity? The hidden output entity for this combinator, if any.

---@param combinator Cybersyn.Combinator.Ephemeral?
---@return boolean?
local function is_valid(combinator)
	return combinator and combinator.entity and combinator.entity.valid
end
combinator_api.is_valid = is_valid

---Check if an ephemeral combinator is a ghost.
---@param combinator Cybersyn.Combinator.Ephemeral?
---@return boolean is_ghost `true` if combinator is a ghost
---@return boolean is_valid `true` if combinator is valid, ghost or no
function combinator_api.is_ghost(combinator)
	if (not combinator) or (not combinator.entity) or (not combinator.entity.valid) then return false, false end
	if combinator.entity.name == "entity-ghost" then return true, true else return false, true end
end

---Determine if an entity is a valid combinator or ghost combinator.
---@param entity LuaEntity
---@return boolean #`true` if entity is a combinator or ghost
function combinator_api.is_combinator_or_ghost_entity(entity)
	if not entity or not entity.valid then return false end
	local true_name = entity.name == "entity-ghost" and entity.ghost_name or entity.name
	return true_name == "cybersyn2-combinator"
end

---Retrieve a combinator state from storage by its entity's `unit_number`.
---@param unit_number UnitNumber?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.Combinator.Internal?
function combinator_api.get_combinator(unit_number, skip_validation)
	if not unit_number then return nil end
	local combinator = storage.combinators[unit_number]
	if skip_validation then
		return combinator
	else
		return is_valid(combinator) and combinator or nil
	end
end

---Get the id of the node associated with this combinator, if any.
---@param combinator Cybersyn.Combinator
---@return Id?
function combinator_api.get_associated_node_id(combinator)
	return combinator.node_id
end

---Get the node associated with this combinator if any, optionally filtering
---by node type.
---@param combinator Cybersyn.Combinator
---@param node_type string?
---@return Cybersyn.Node?
function combinator_api.get_associated_node(combinator, node_type)
	local node = storage.nodes[combinator.node_id or ""]
	if node and (not node_type or node.type == node_type) then return node end
end

---Attempt to convert an ephemeral combinator reference to a realized combinator reference.
---@param ephemeral Cybersyn.Combinator.Ephemeral
---@return Cybersyn.Combinator?
function combinator_api.realize(ephemeral)
	if ephemeral and ephemeral.entity and ephemeral.entity.valid then
		local combinator = storage.combinators[ephemeral.entity.unit_number]
		if combinator == ephemeral or is_valid(combinator) then return combinator end
	end
	return nil
end

---Determines if the given entity is a valid combinator *or* ghost and returns
---an ephemeral reference to it if so, nil if not.
---@param entity LuaEntity
---@return Cybersyn.Combinator.Ephemeral?
function combinator_api.entity_to_ephemeral(entity)
	if combinator_api.is_combinator_or_ghost_entity(entity) then
		return { entity = entity }
	end
	return nil
end

---Locate all `LuaEntity`s corresponding to combinators within the given area.
---@param surface LuaSurface
---@param area BoundingBox?
---@param position MapPosition?
---@param radius number?
---@return LuaEntity[]
function combinator_api.find_combinator_entities(surface, area, position, radius)
	return surface.find_entities_filtered({
		area = area,
		position = position,
		radius = radius,
		name = "cybersyn2-combinator",
	})
end

---Locate all `LuaEntity`s corresponding to combinator ghosts within the given area.
---@param surface LuaSurface
---@param area BoundingBox?
---@param position MapPosition?
---@param radius number?
---@return LuaEntity[]
function combinator_api.find_combinator_entity_ghosts(surface, area, position, radius)
	return surface.find_entities_filtered({
		area = area,
		position = position,
		radius = radius,
		ghost_name = "cybersyn2-combinator",
	})
end
