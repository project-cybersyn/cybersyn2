--------------------------------------------------------------------------------
-- Lifecycle management for combinators.
-- Combinator state is only created/destroyed in this module.
-- We also manage the physical storage of combinator settings here, as that has
-- numerous cross-cutting concerns with lifecycle.
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local tlib = require("__cybersyn2__.lib.table")
local flib_table = require("__flib__.table")

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

---@param combinator_entity LuaEntity
---@return LuaEntity?
local function find_settings_entity(combinator_entity)
	local ents = combinator_entity.surface.find_entities_filtered({
		name = "cybersyn2-combinator-settings",
		position = combinator_entity.position,
		radius = 0.3,
	})
	return ents[1]
end

---@param combinator_entity LuaEntity
---@return LuaEntity?
local function find_settings_ghost(combinator_entity)
	local ents = combinator_entity.surface.find_entities_filtered({
		ghost_name = "cybersyn2-combinator-settings",
		position = combinator_entity.position,
		radius = 0.3,
	})
	return ents[1]
end

-- Sttings storage notes:
-- - When storage_ghost is placed, check for combi_ghost and move
-- settings to tags of combi_ghost
-- - When combi_ghost is placed, scan for storage_ghost and decode
-- settings into tags
-- - When combi is placed:
-- -- Read tags into cache as authoritative. If no tags, pop defaults.
-- -- Check for hidden entity OR ghost in range.
-- -- If ghost and entity, delete ghost.
-- -- If ghost and no entity, revive ghost.
-- -- If no ghost and no entity, create entity.
-- -- Encode cache onto entity.

-- Test scenarios:
-- TODO: build from hand
-- TODO: build from shift ghost
-- TODO: build from blueprint in inventory
-- TODO: build from book in inventory
-- TODO: build from BP in library
-- TODO: build from book in library
-- TODO: build by pipette from ghost

---@param display_panel LuaEntity A *valid* reference to a display panel.
---@return Tags? #The decoded tags
local function decode_tags_from_display_panel(display_panel)
	local beh = display_panel.get_control_behavior() --[[@as LuaDisplayPanelControlBehavior]]
	if not beh then
		log.trace("decode_tags_from_display_panel: No control behavior found")
		return nil
	end
	local strs = tlib.map(beh.messages, function(message)
		return message.text or ""
	end)
	local t = helpers.json_to_table(table.concat(strs))
	if type(t) == "table" then
		return t
	else
		log.trace("decode_tags_from_display_panel: No valid JSON found")
		return nil
	end
end

---Encode the given tags into the display panel.
---@param tags Tags The tags to encode.
---@param display_panel LuaEntity A *valid* reference to a display panel.
---@return boolean #`true` if the tags were encoded, `false` if not.
local function encode_tags_to_display_panel(tags, display_panel)
	local beh = display_panel.get_or_create_control_behavior() --[[@as LuaDisplayPanelControlBehavior]]
	if not beh then
		log.trace("encode_tags_to_display_panel: Couldnt make control behavior")
		return false
	end
	local json = helpers.table_to_json(tags)
	if not json then
		log.trace("encode_tags_to_display_panel: Couldnt encode to json")
		return false
	end
	-- Chop json into chunks of length 500
	local chunks = {}
	for i = 1, #json, 500 do
		chunks[#chunks + 1] = json:sub(i, i + 499)
	end
	beh.messages = tlib.map(chunks, function(chunk)
		return {
			text = chunk,
			condition = {
				first_signal = { name = "signal-Z", type = "virtual" },
				comparator = ">",
				constant = 0,
			},
		}
	end)
	return true
end

---@param combinator_entity LuaEntity
local function get_raw_values(combinator_entity)
	-- If real combinator, should be in the cache.
	local id = combinator_entity.unit_number
	---@type Cybersyn.Storage
	local data = storage
	if data.combinator_settings_cache[id] then return data.combinator_settings_cache[id] end

	-- Must be a ghost at this point, otherwise there's a problem.
	if combinator_entity.name ~= "entity-ghost" or combinator_entity.ghost_name ~= "cybersyn2-combinator" then
		log.warn("Combinator is not a ghost and has no settings cache", combinator_entity)
		-- TODO: silent failure?
		return {}
	end

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
	if not combinator.settings_entity then
		log.warn("Real combinator has no settings entity", combinator_entity)
		return false
	end
	---@type Cybersyn.Storage
	local data = storage
	if not data.combinator_settings_cache[id] then
		log.warn("Real combinator has no settings cache", combinator_entity)
		return false
	end
	data.combinator_settings_cache[id] = values
	if not encode_tags_to_display_panel(data.combinator_settings_cache[id], combinator.settings_entity) then
		log.warn("Failed to encode settings to hidden entity", combinator.settings_entity)
	end
	return true
end

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
	-- If not ghost, update cache and re-encode cache to hidden entity.
	local id = combinator_entity.unit_number
	local combinator = combinator_api.get_combinator(id, true)
	if not combinator then
		log.warn("Real combinator has no state", combinator_entity)
		return false
	end
	if not combinator.settings_entity then
		log.warn("Real combinator has no settings entity", combinator_entity)
		return false
	end
	---@type Cybersyn.Storage
	local data = storage
	if not data.combinator_settings_cache[id] then
		log.warn("Real combinator has no settings cache", combinator_entity)
		return false
	end
	data.combinator_settings_cache[id][key] = value
	if not encode_tags_to_display_panel(data.combinator_settings_cache[id], combinator.settings_entity) then
		log.warn("Failed to encode settings to hidden entity", combinator.settings_entity)
	end
	return true
end

on_built_combinator(function(combinator_entity, tags)
	local comb_id = combinator_entity.unit_number --[[@as UnitNumber]]
	local comb = combinator_api.get_combinator(comb_id, true)
	if comb then
		-- Should be impossible
		log.error("Duplicate combinator unit number, should be impossible.", comb_id)
		return
	end
	comb = create_combinator_state(combinator_entity)

	-- Revive or create the hidden settings entity.
	local settings_entity = find_settings_entity(combinator_entity)
	local settings_ghost = find_settings_ghost(combinator_entity)

	if settings_entity then
		log.trace("Settings entity already exists")
		-- Entity already there, destroy ghost
		if settings_ghost then settings_ghost.destroy() end
	else
		if settings_ghost then
			-- Ghost already there, revive it
			log.trace("Reviving settings entity")
			_, settings_entity = settings_ghost.silent_revive()
			if not settings_entity then
				error("Failed to revive hidden settings ghost")
			end
		else
			-- Create new settings entity
			log.trace("Creating new settings entity")
			settings_entity = combinator_entity.surface.create_entity({
				name = "cybersyn2-combinator-settings",
				position = combinator_entity.position,
				force = combinator_entity.force,
			})
		end
	end
	if not settings_entity then
		error("Failed to create or find hidden settings entity")
	end
	comb.settings_entity = settings_entity

	-- Decode tags from hidden settings entity
	local new_tags = decode_tags_from_display_panel(settings_entity) or {}
	-- Assign tags inherited from combinator ghost
	tlib.assign(new_tags, tags or {})
	-- Store settings in cache
	---@type Cybersyn.Storage
	local data = storage
	data.combinator_settings_cache[comb.id] = new_tags

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

	-- Destroy any possible companion entities.
	if comb.settings_entity and comb.settings_entity.valid then
		log.trace("Destroying hidden settings entity")
		comb.settings_entity.destroy()
		comb.settings_entity = nil
	end
	local e1 = find_settings_entity(combinator_entity)
	if e1 then e1.destroy() end
	local e2 = find_settings_ghost(combinator_entity)
	if e2 then e2.destroy() end

	-- Clear settings cache
	---@type Cybersyn.Storage
	local data = storage
	data.combinator_settings_cache[comb.id] = nil

	destroy_combinator_state(comb.id)
end)

on_built_combinator_settings_ghost(function(settings_ghost)
	-- Move settings into tags of ghost if needed
	local combinator_ghost = combinator_api.find_combinator_entity_ghosts(settings_ghost.surface, nil,
		settings_ghost.position, 0.1)[1]
	if combinator_ghost then
		-- If combinator ghost already has settings, those govern.
		local cg_tags = combinator_ghost.tags
		if cg_tags and next(cg_tags) then return end

		-- Otherwise, decode and assign.
		combinator_ghost.tags = decode_tags_from_display_panel(settings_ghost) or {}
	end
end)

on_built_combinator_ghost(function(combinator_ghost)
	local settings_ghost = find_settings_ghost(combinator_ghost)
	if settings_ghost then
		-- If combinator ghost already has settings, those govern.
		local cg_tags = combinator_ghost.tags
		if cg_tags and next(cg_tags) then return end

		-- Otherwise, decode and assign.
		combinator_ghost.tags = decode_tags_from_display_panel(settings_ghost) or {}
	end
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
