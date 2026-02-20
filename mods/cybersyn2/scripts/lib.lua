local mlib = require("lib.core.math.pos")
local tlib = require("lib.core.table")

local distsq = mlib.pos_distsq
local pos_get = mlib.pos_get
local sqrt = math.sqrt
local INF = math.huge
local COMBINATOR_NAME = _G.cs2.COMBINATOR_NAME
local EMPTY = tlib.EMPTY_STRICT

local DIFFERENT_SURFACE_DISTANCE = 1000000000

---Return the distance-squared between the map positions of the given two
---entities. Returns a large distance if they are on different surfaces.
---@param e1 LuaEntity
---@param e2 LuaEntity
---@return number
---@nodiscard
function _G.cs2.lib.distsq(e1, e2)
	if e1.surface_index ~= e2.surface_index then
		return DIFFERENT_SURFACE_DISTANCE
	end
	return distsq(e1.position, e2.position)
end

---Return the distance between the map positions of the given two entities.
---Returns a large distance if they are on different surfaces.
---@param e1 LuaEntity
---@param e2 LuaEntity
---@return number
---@nodiscard
function _G.cs2.lib.dist(e1, e2)
	if e1.surface_index ~= e2.surface_index then
		return DIFFERENT_SURFACE_DISTANCE
	end
	return sqrt(distsq(e1.position, e2.position))
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
function _G.cs2.find_associable_combinator_entities(stop_entity)
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
---@param value table
function _G.cs2.ring_buffer_log_write(log, value)
	value.tick = game.tick
	log.log_buffer[log.log_current] = value
	log.log_current = log.log_current + 1
	if log.log_current > log.log_size then log.log_current = 1 end
end

---Given a combinator, find the nearby rail or stop that may trigger an
---association.
---@param combinator_entity LuaEntity A *valid* combinator entity.
---@return LuaEntity? stop_entity The closest-to-front train stop within the combinator's association zone.
---@return LuaEntity? rail_entity The closest-to-front straight rail with a train stop within the combinator's association zone.
function _G.cs2.lib.find_associable_entities_for_combinator(combinator_entity)
	local pos = combinator_entity.position
	local pos_x, pos_y = pos_get(pos)
	local search_area = {
		{ pos_x - 1.5, pos_y - 1.5 },
		{ pos_x + 1.5, pos_y + 1.5 },
	}
	local stop = nil
	local rail = nil
	local stop_dist = INF
	local rail_dist = INF
	local entities = combinator_entity.surface.find_entities_filtered({
		area = search_area,
		type = {
			"train-stop",
			"straight-rail",
		},
	})
	for _, cur_entity in pairs(entities) do
		if cur_entity.name == "train-stop" then
			local dist = distsq(pos, cur_entity.position)
			if dist < stop_dist then
				stop_dist = dist
				stop = cur_entity
			end
		elseif cur_entity.type == "straight-rail" then
			-- Prefer rails with stops, then prefer rails nearer the
			-- front of the combinator.
			if cs2.find_stop_from_rail(cur_entity) then
				local dist = distsq(pos, cur_entity.position)
				if dist < rail_dist then
					rail_dist = dist
					rail = cur_entity
				end
			end
		end
	end
	return stop, rail
end

---@param cset {[int64]: true}
---@param idx int64|nil
local function comb_iter(cset, idx)
	local next_idx = next(cset, idx)
	if next_idx then return next_idx, cs2.get_combinator(next_idx, true) end
end

---Lua iterator over all combinators associated with a node.
---@param node Cybersyn.Node
function _G.cs2.iterate_combinators(node)
	return comb_iter, node.combinator_set or EMPTY, nil
end
