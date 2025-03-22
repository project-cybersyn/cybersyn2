--------------------------------------------------------------------------------
-- Lifecycle management for combinators.
-- Combinator state is only created/destroyed in this module.
-- We also manage the physical storage of combinator settings here, as that has
-- numerous cross-cutting concerns with lifecycle.
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local tlib = require("__cybersyn2__.lib.table")
local bplib = require("__cybersyn2__.lib.blueprint")

local is_combinator_or_ghost_entity = combinator_api.is_combinator_or_ghost_entity

---@param combinator_entity LuaEntity A *valid* reference to a non-ghost combinator.
---@return Cybersyn.Combinator.Internal
local function create_combinator_state(combinator_entity)
	local combinator_id = combinator_entity.unit_number
	if not combinator_id then
		-- Should be impossible. Have to crash here as this function cant return nil.
		error("Combinator entity has no unit number.")
	end
	storage.combinators[combinator_id] = {
		id = combinator_id,
		entity = combinator_entity,
	} --[[@as Cybersyn.Combinator.Internal]]

	return storage.combinators[combinator_id]
end

---@param combinator_id UnitNumber
---@return boolean `true` if the combinator was removed, `false` if it was not found.
local function destroy_combinator_state(combinator_id)
	if storage.combinators[combinator_id] then
		storage.combinators[combinator_id] = nil
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Settings storage.
--------------------------------------------------------------------------------

-- Test scenarios:
-- TODO: build from hand
-- TODO: build from shift ghost
-- TODO: build from blueprint in inventory
-- TODO: build from book in inventory
-- TODO: build from BP in library
-- TODO: build from book in library
-- TODO: build by pipette from ghost

---@param combinator_entity LuaEntity A *valid* combinator or combinator ghost entity.
---@return Tags
local function get_raw_values(combinator_entity)
	-- If real combinator, should be in the cache.
	local id = combinator_entity.unit_number
	if storage.combinator_settings_cache[id] then return storage.combinator_settings_cache[id] end

	return combinator_entity.tags or {}
end

---@param combinator_entity LuaEntity
---@param values Tags
local function set_raw_values(combinator_entity, values)
	-- Defensive copy to avoid possible storage cross-references
	values = tlib.deep_copy(values, true)
	-- If ghost, store in tags.
	if combinator_entity.name == "entity-ghost" then
		combinator_entity.tags = values
		return true
	end
	-- If not ghost, update cache and re-encode cache to hidden entity.
	local id = combinator_entity.unit_number --[[@as UnitNumber]]
	local combinator = combinator_api.get_combinator(id, true)
	if not combinator then
		log.warn("Real combinator has no state", combinator_entity)
		return false
	end
	if not storage.combinator_settings_cache[id] then
		log.warn("Real combinator has no settings cache", combinator_entity)
		return false
	end
	storage.combinator_settings_cache[id] = values
	return true
end

--------------------------------------------------------------------------------
-- Raw storage API. This should only be used by the higher level combinator
-- settings API.
--------------------------------------------------------------------------------

---Obtain the raw value of a storage key in physical combinator settings
---storage.
---@param combinator_entity LuaEntity A *valid* combinator or ghost entity
---@param key string
---@return boolean|string|number|Tags|nil
function combinator_api.get_raw_value(combinator_entity, key)
	return get_raw_values(combinator_entity)[key]
end

---Store a raw value into the key of physical combinator settings storage.
---DO NOT use this to change combinator settings; instead use the
---combinator settings API.
---@param combinator_entity LuaEntity A *valid* combinator or ghost entity
---@param key string
---@param value boolean|string|number|Tags|nil
---@return boolean #`true` if the value was stored, `false` if not.
function combinator_api.set_raw_value(combinator_entity, key, value)
	-- If ghost, store in tags.
	if combinator_entity.name == "entity-ghost" then
		local tags = combinator_entity.tags or {}
		tags[key] = value
		combinator_entity.tags = tags
		return true
	end
	-- If not ghost, update cache
	local id = combinator_entity.unit_number
	local combinator = combinator_api.get_combinator(id, true)
	if not combinator then
		log.warn("Real combinator has no state", combinator_entity)
		return false
	end
	if not storage.combinator_settings_cache[id] then
		log.warn("Real combinator has no settings cache", combinator_entity)
		return false
	end
	storage.combinator_settings_cache[id][key] = value
	return true
end

--------------------------------------------------------------------------------
-- Combinator lifecycle events.
--------------------------------------------------------------------------------

on_built_combinator(function(combinator_entity, tags)
	local comb_id = combinator_entity.unit_number --[[@as UnitNumber]]
	local comb = combinator_api.get_combinator(comb_id, true)
	if comb then
		-- Should be impossible
		log.error("Duplicate combinator unit number, should be impossible.", comb_id)
		return
	end
	comb = create_combinator_state(combinator_entity)

	-- Store settings in cache
	storage.combinator_settings_cache[comb.id] = tags or {}

	-- Create hidden output entity
	local out = combinator_entity.surface.create_entity({
		name = "cybersyn2-output",
		position = combinator_entity.position,
		force = combinator_entity.force,
		create_build_effect_smoke = false,
	})
	if not out then
		error("fatal error: could not create hidden output entity")
	end
	comb.output_entity = out

	-- Wire hidden entity to combinator
	local comb_red = combinator_entity.get_wire_connector(defines.wire_connector_id.circuit_red, true)
	local out_red = out.get_wire_connector(defines.wire_connector_id.circuit_red, true)
	out_red.connect_to(comb_red, false, defines.wire_origin.script)
	local comb_green = combinator_entity.get_wire_connector(defines.wire_connector_id.circuit_green, true)
	local out_green = out.get_wire_connector(defines.wire_connector_id.circuit_green, true)
	out_green.connect_to(comb_green, false, defines.wire_origin.script)

	raise_combinator_created(comb)
end)

on_broken_combinator(function(combinator_entity)
	local comb = combinator_api.get_combinator(combinator_entity.unit_number, true)
	if not comb then return end
	comb.is_being_destroyed = true

	raise_combinator_destroyed(comb)

	-- Destroy hidden settings entity
	if comb.output_entity and comb.output_entity.valid then
		comb.output_entity.destroy()
	end

	-- Clear settings cache
	storage.combinator_settings_cache[comb.id] = nil

	destroy_combinator_state(comb.id)
end)

on_entity_settings_pasted(function(event)
	local source = combinator_api.entity_to_ephemeral(event.source)
	local dest = combinator_api.entity_to_ephemeral(event.destination)
	if source and dest then
		local vals = get_raw_values(source.entity)
		set_raw_values(dest.entity, vals)
		raise_combinator_or_ghost_setting_changed(dest, nil, nil, nil)
	end
end)

--------------------------------------------------------------------------------
-- Handle when user pastes a blueprint, which may disrupt the settings
-- of multiple combinators.
--------------------------------------------------------------------------------

-- TODO: update for tags

---@param bp_entity BlueprintEntity
---@return boolean
local function bp_combinator_filter(bp_entity)
	return bp_entity.name == "cybersyn2-combinator"
end

on_built_blueprint(function(player, event)
	local blueprintish = bplib.get_actual_blueprint(player, player.cursor_record, player.cursor_stack)
	if blueprintish then
		local bp_entities = blueprintish.get_blueprint_entities()
		if not bp_entities then return end
		local overlap_map = bplib.get_overlapping_entities(
			bp_entities,
			player.surface,
			event.position,
			event.direction,
			event.flip_horizontal,
			event.flip_vertical,
			bp_combinator_filter
		)
		for i, entity in pairs(overlap_map) do
			local comb = combinator_api.get_combinator(entity.unit_number, true)
			local tags = bp_entities[i].tags or {}
			if comb then
				log.trace("Combinator lifecycle: combinator settings pasted via blueprint",
					entity)
				set_raw_values(entity, tags)
				raise_combinator_or_ghost_setting_changed(comb, nil, nil, nil)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Extract settings tags on blueprint setup.
--------------------------------------------------------------------------------

on_blueprint_setup(function(event)
	bplib.save_tags(event, function(entity)
		if is_combinator_or_ghost_entity(entity) then
			return get_raw_values(entity)
		end
	end)
end)
