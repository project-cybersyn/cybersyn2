--------------------------------------------------------------------------------
-- Lifecycle management for combinators.
-- Combinator state is only created/destroyed in this module.
-- We also manage the physical storage of combinator settings here, as that has
-- numerous cross-cutting concerns with lifecycle.
--------------------------------------------------------------------------------

local stlib = require("__cybersyn2__.lib.strace")
local log = require("__cybersyn2__.lib.logging")
local tlib = require("__cybersyn2__.lib.table")
local bplib = require("__cybersyn2__.lib.blueprint")
local cs2 = _G.cs2
local Combinator = _G.cs2.Combinator
local EphemeralCombinator = _G.cs2.EphemeralCombinator

local strace = stlib.strace
local ERROR = stlib.ERROR
local TRACE = stlib.TRACE
local entity_is_combinator_or_ghost = _G.cs2.lib.entity_is_combinator_or_ghost
local COMBINATOR_NAME = _G.cs2.COMBINATOR_NAME
local get_raw_settings = _G.cs2.get_raw_settings

--------------------------------------------------------------------------------
-- Combinator lifecycle events.
--------------------------------------------------------------------------------

cs2.on_built_combinator(function(combinator_entity, tags)
	local comb_id = combinator_entity.unit_number --[[@as UnitNumber]]
	local comb = Combinator.get(comb_id, true)
	if comb then
		-- Should be impossible
		return strace(
			ERROR,
			"message",
			"Duplicate combinator unit number, should be impossible.",
			comb_id
		)
	end
	comb = Combinator.new(combinator_entity)

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
	local comb_red = combinator_entity.get_wire_connector(
		defines.wire_connector_id.circuit_red,
		true
	)
	local out_red =
		out.get_wire_connector(defines.wire_connector_id.circuit_red, true)
	out_red.connect_to(comb_red, false, defines.wire_origin.script)
	local comb_green = combinator_entity.get_wire_connector(
		defines.wire_connector_id.circuit_green,
		true
	)
	local out_green =
		out.get_wire_connector(defines.wire_connector_id.circuit_green, true)
	out_green.connect_to(comb_green, false, defines.wire_origin.script)

	cs2.raise_combinator_created(comb)
end)

cs2.on_broken_combinator(function(combinator_entity)
	local comb = Combinator.get(combinator_entity.unit_number, true)
	if not comb then return end
	comb.is_being_destroyed = true

	cs2.raise_combinator_destroyed(comb)

	-- Destroy hidden settings entity
	if comb.output_entity and comb.output_entity.valid then
		comb.output_entity.destroy()
	end

	-- Clear settings cache
	storage.combinator_settings_cache[comb.id] = nil

	comb:destroy_state()
end)

cs2.on_entity_settings_pasted(function(event)
	local source = EphemeralCombinator.new(event.source)
	local dest = EphemeralCombinator.new(event.destination)
	if source and dest then
		local vals = source:get_raw_settings()
		dest:set_raw_settings(vals)
		cs2.raise_combinator_or_ghost_setting_changed(dest, nil, nil, nil)
	end
end)

--------------------------------------------------------------------------------
-- Blueprinting combinators
--------------------------------------------------------------------------------

-- TODO: update for tags

---@param bp_entity BlueprintEntity
---@return boolean
local function bp_combinator_filter(bp_entity)
	return bp_entity.name == COMBINATOR_NAME
end

cs2.on_built_blueprint(function(player, event)
	local blueprintish = bplib.get_actual_blueprint(
		player,
		player.cursor_record,
		player.cursor_stack
	)
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
			local comb = Combinator.get(entity.unit_number, true)
			local tags = bp_entities[i].tags or {}
			if comb then
				strace(
					TRACE,
					"message",
					"Combinator lifecycle: combinator settings pasted via blueprint",
					entity
				)
				comb:set_raw_settings(tags)
				cs2.raise_combinator_or_ghost_setting_changed(comb, nil, nil, nil)
			end
		end
	end
end)

-- Extract settings tags on blueprint setup.
cs2.on_blueprint_setup(function(event)
	bplib.save_tags(event, function(entity)
		if entity_is_combinator_or_ghost(entity) then
			return get_raw_settings(entity)
		end
	end)
end)
