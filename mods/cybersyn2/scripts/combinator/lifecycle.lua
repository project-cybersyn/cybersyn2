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

-- fix missing Factorio API types
-- this comes from Harag's original CS1 DC patch
-- TODO: move this to a better place

---@class DeciderCombinatorOutput -- The Factorio Lua API only defines this as 'table'
---@field public copy_count_from_input boolean
---@field public constant int32
---@field public signal SignalFilter

---@class DeciderCombinatorSignalNetworks
---@field public green boolean?
---@field public red boolean?

---@class DeciderCombinatorCondition -- The Factorio Lua API only defines this as 'table'
---@field public comparator "="|">"|"<"|"≥"|">="|"≤"|"<="|"≠"|"!="
---@field public compare_type "and"|"or"|nil
---@field public first_signal SignalFilter?
---@field public first_signal_networks DeciderCombinatorSignalNetworks?
---@field public constant int32?
---@field public second_signal SignalFilter?
---@field public second_signal_networks DeciderCombinatorSignalNetworks?

local NO_NETWORKS = { red = false, green = false }

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
			"cs2",
			"combinator",
			"message",
			"Duplicate combinator unit number, should be impossible.",
			comb_id
		)
	end
	comb = Combinator.new(combinator_entity)

	-- Store settings in cache
	storage.combinator_settings_cache[comb.id] = tags
		or _G.cs2.DEFAULT_COMBINATOR_SETTINGS

	-- Add LHS conditions. First is so we can control what displays in the
	-- combinator's window, second is generic "always-true"
	local beh = combinator_entity.get_or_create_control_behavior() --[[@as LuaDeciderCombinatorControlBehavior]]
	beh.parameters = {
		conditions = {
			{
				comparator = "=",
				first_signal = nil,
				second_signal = nil,
				compare_type = "or",
				first_signal_networks = NO_NETWORKS,
				second_signal_networks = NO_NETWORKS,
			},
			{
				comparator = "=",
				first_signal = nil,
				second_signal = nil,
				compare_type = "or",
				first_signal_networks = NO_NETWORKS,
				second_signal_networks = NO_NETWORKS,
			},
		},
		outputs = {},
	}

	-- Crosswire i/o
	local i_red = combinator_entity.get_wire_connector(
		defines.wire_connector_id.combinator_input_red,
		true
	)
	local o_red = combinator_entity.get_wire_connector(
		defines.wire_connector_id.combinator_output_red,
		true
	)
	i_red.connect_to(o_red, false, defines.wire_origin.script)

	local i_green = combinator_entity.get_wire_connector(
		defines.wire_connector_id.combinator_input_green,
		true
	)
	local o_green = combinator_entity.get_wire_connector(
		defines.wire_connector_id.combinator_output_green,
		true
	)
	i_green.connect_to(o_green, false, defines.wire_origin.script)

	cs2.raise_combinator_created(comb)
end)

cs2.on_broken_combinator(function(combinator_entity)
	local comb = Combinator.get(combinator_entity.unit_number, true)
	if not comb then return end
	comb.is_being_destroyed = true

	cs2.raise_combinator_destroyed(comb)

	-- TODO: destroy associated entities

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
	-- Save config tags into blueprint
	bplib.save_tags(event, function(entity)
		if entity_is_combinator_or_ghost(entity) then
			return get_raw_settings(entity)
		end
	end)
	-- Remove decider combinator outputs
	local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
	local blueprintish =
		bplib.get_actual_blueprint(player, event.record, event.stack)
	if not blueprintish then return end
	local bp_entities = blueprintish.get_blueprint_entities()
	if not bp_entities then return end
	local changed = false
	for _, entity in pairs(bp_entities) do
		if entity.name == COMBINATOR_NAME then
			if
				entity.control_behavior and entity.control_behavior.decider_conditions
			then
				entity.control_behavior.decider_conditions.conditions = {}
				entity.control_behavior.decider_conditions.outputs = {}
				changed = true
			end
		end
	end
	if changed then blueprintish.set_blueprint_entities(bp_entities) end
end)
