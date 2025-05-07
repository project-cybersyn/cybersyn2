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

---@param combinator_entity LuaEntity
local function create_combinator(combinator_entity)
	local comb = Combinator.new(combinator_entity)

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

	cs2.raise_combinator_created(comb)
end

---@param comb Cybersyn.Combinator
---@param is_reset boolean
local function destroy_combinator(comb, is_reset)
	comb.is_being_destroyed = true

	cs2.raise_combinator_destroyed(comb, is_reset)

	if comb.associated_entities then
		for _, entity in pairs(comb.associated_entities) do
			if entity.valid then entity.destroy() end
		end
	end
end

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

	-- Copy settings from tags to cache
	storage.combinator_settings_cache[comb_id] =
		tlib.deep_copy(tags or cs2.DEFAULT_COMBINATOR_SETTINGS, true)

	create_combinator(combinator_entity)
end)

cs2.on_built_combinator_ghost(function(ghost)
	-- Apply default settings to ghosts when built.
	if not ghost.tags then
		ghost.tags = tlib.deep_copy(cs2.DEFAULT_COMBINATOR_SETTINGS, true)
	end
end)

cs2.on_broken_combinator(function(combinator_entity)
	local comb = Combinator.get(combinator_entity.unit_number, true)
	if not comb then return end
	destroy_combinator(comb, false)

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

cs2.on_blueprint_built(function(bpinfo)
	local overlap_map = bpinfo:get_overlap(bp_combinator_filter)
	if overlap_map and next(overlap_map) then
		local bp_entities = bpinfo:get_entities() --[[@as BlueprintEntity[] ]]
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

cs2.on_blueprint_setup(function(bpinfo)
	local bp_entities = bpinfo:get_entities()
	if not bp_entities then return end

	-- XXX: remove this
	-- Remove decider combinator outputs
	-- local changed = false
	-- for _, entity in pairs(bp_entities) do
	-- 	if entity.name == COMBINATOR_NAME then
	-- 		if
	-- 			entity.control_behavior and entity.control_behavior.decider_conditions
	-- 		then
	-- 			entity.control_behavior.decider_conditions.conditions = {
	-- 				{
	-- 					comparator = "=",
	-- 					first_signal_networks = {
	-- 						red = false,
	-- 						green = false,
	-- 					},
	-- 					second_signal_networks = {
	-- 						red = false,
	-- 						green = false,
	-- 					},
	-- 				},
	-- 				{
	-- 					comparator = "=",
	-- 					first_signal_networks = {
	-- 						red = false,
	-- 						green = false,
	-- 					},
	-- 					second_signal_networks = {
	-- 						red = false,
	-- 						green = false,
	-- 					},
	-- 				},
	-- 			}
	-- 			entity.control_behavior.decider_conditions.outputs = {}
	-- 			changed = true
	-- 		end
	-- 	end
	-- end
	-- if changed then bpinfo:set_entities(bp_entities) end

	-- Save config tags into blueprint
	local bp_to_world = bpinfo:get_bp_to_world()
	if not bp_to_world then return end
	for bpid, entity in pairs(bp_to_world) do
		if entity_is_combinator_or_ghost(entity) then
			bpinfo:apply_tags(bpid, get_raw_settings(entity))
		end
	end
end)

--------------------------------------------------------------------------------
-- Combinator hotwiring
--------------------------------------------------------------------------------

---@param combinator Cybersyn.Combinator
local function hotwire_combinator(combinator)
	local mdef = cs2.combinator_modes[combinator.mode or ""]
	if mdef then
		if mdef.is_input then
			combinator:cross_wires(true)
		elseif mdef.is_output then
			combinator:cross_wires(false)
		end
	end
end

cs2.on_combinator_created(hotwire_combinator)
cs2.on_combinator_setting_changed(function(combinator, setting)
	if setting == "mode" or setting == nil then hotwire_combinator(combinator) end
end)

--------------------------------------------------------------------------------
-- Reset
--------------------------------------------------------------------------------
cs2.on_reset(function(reset_data)
	-- Need to hand off combinator settings so they can be restored after reset.
	reset_data.combinator_settings_cache = storage.combinator_settings_cache

	-- Must destroy all hidden associated entities, otherwise they will
	-- be double-created.
	for _, comb in pairs(storage.combinators) do
		if comb.associated_entities then
			for _, entity in pairs(comb.associated_entities) do
				if entity.valid then entity.destroy() end
			end
		end
	end
end)

cs2.on_startup(function(reset_data)
	-- Restore combinator settings after reset.
	if reset_data.combinator_settings_cache then
		storage.combinator_settings_cache = reset_data.combinator_settings_cache
	end

	-- Recreate all combinators in the world.
	for _, surface in pairs(game.surfaces) do
		for _, comb_entity in
			pairs(surface.find_entities_filtered({ name = COMBINATOR_NAME }))
		do
			if not storage.combinators[comb_entity.unit_number] then
				create_combinator(comb_entity)
			end
		end
	end
end)
