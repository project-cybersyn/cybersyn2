local mlib = require("__cybersyn2__.lib.math")

local distsq = mlib.pos_distsq
local INF = math.huge
local COMBINATOR_NAME = _G.cs2.COMBINATOR_NAME

local DIFFERENT_SURFACE_DISTANCE = 1000000000

---Return the distance-squared between the map positions of the given two
---entities. Returns a large distance if they are on different surfaces.
---@param e1 LuaEntity
---@param e2 LuaEntity
function _G.cs2.lib.distsq(e1, e2)
	if e1.surface_index ~= e2.surface_index then
		return DIFFERENT_SURFACE_DISTANCE
	end
	return distsq(e1.position, e2.position)
end

---Locate all `LuaEntity`s corresponding to train stops within the given area.
---@param surface LuaSurface
---@param area BoundingBox?
---@param position MapPosition?
---@param radius number?
---@return LuaEntity[]
function _G.cs2.lib.find_stop_entities(surface, area, position, radius)
	return surface.find_entities_filtered({
		area = area,
		position = position,
		radius = radius,
		name = "train-stop",
	})
end

---Locate all combinators that could potentially be associated to a stop.
---@param stop_entity LuaEntity A *valid* train stop entity.
---@return LuaEntity[]
function _G.cs2.lib.find_associable_combinators(stop_entity)
	local pos_x = stop_entity.position.x
	local pos_y = stop_entity.position.y
	return cs2.lib.find_combinator_entities(stop_entity.surface, {
		{ pos_x - 2, pos_y - 2 },
		{ pos_x + 2, pos_y + 2 },
	})
end

---Locate all `LuaEntity`s corresponding to combinator ghosts within the given area.
---@param surface LuaSurface
---@param area BoundingBox?
---@param position MapPosition?
---@param radius number?
---@return LuaEntity[]
function _G.cs2.lib.find_combinator_ghosts(surface, area, position, radius)
	return surface.find_entities_filtered({
		area = area,
		position = position,
		radius = radius,
		ghost_name = COMBINATOR_NAME,
	})
end

---@param entity LuaEntity?
function _G.cs2.lib.entity_is_combinator_or_ghost(entity)
	if not entity or not entity.valid then return false end
	local true_name = entity.name == "entity-ghost" and entity.ghost_name
		or entity.name
	return true_name == COMBINATOR_NAME
end

---@param entity LuaEntity?
function _G.cs2.lib.entity_is_combinator(entity)
	if not entity or not entity.valid then return false end
	return entity.name == COMBINATOR_NAME
end

---Locate all `LuaEntity`s corresponding to combinators within the given area.
---@param surface LuaSurface
---@param area BoundingBox?
---@param position MapPosition?
---@param radius number?
---@return LuaEntity[]
function _G.cs2.lib.find_combinator_entities(
	surface,
	area,
	position,
	radius
)
	return surface.find_entities_filtered({
		area = area,
		position = position,
		radius = radius,
		name = COMBINATOR_NAME,
	})
end

---@param player LuaPlayer
---@param message LocalisedString
---@param play_sound boolean?
---@param position MapPosition?
function _G.cs2.lib.flying_text(player, message, play_sound, position)
	player.create_local_flying_text({
		text = message,
		create_at_cursor = not position,
		position = position,
	})
	if play_sound then player.play_sound({ path = "utility/cannot_build" }) end
end

---@param log RingBufferLog
---@param value any
function _G.cs2.ring_buffer_log_write(log, value)
	log.log_buffer[log.log_current] = value
	log.log_current = log.log_current + 1
	if log.log_current > log.log_size then log.log_current = 1 end
end
