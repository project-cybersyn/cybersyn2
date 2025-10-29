--------------------------------------------------------------------------------
-- Lifecycle management for combinators.
-- Combinator state is only created/destroyed in this module.
--------------------------------------------------------------------------------

local stlib = require("lib.core.strace")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local cs2 = _G.cs2
local Combinator = _G.cs2.Combinator

local EMPTY = tlib.EMPTY_STRICT
local strace = stlib.strace
local ERROR = stlib.ERROR
local TRACE = stlib.TRACE
local entity_is_combinator_or_ghost = _G.cs2.lib.entity_is_combinator_or_ghost
local COMBINATOR_NAME = _G.cs2.COMBINATOR_NAME
local get_raw_settings = _G.cs2.get_raw_settings

local NO_NETWORKS = { red = false, green = false }

--------------------------------------------------------------------------------
-- Combinator lifecycle events.
--------------------------------------------------------------------------------

---@param combinator_entity LuaEntity
local function clear_combinator_outputs(combinator_entity)
	-- Clear outputs of combinator
	local beh = combinator_entity.get_or_create_control_behavior()
	if not beh then return end
	---@cast beh LuaDeciderCombinatorControlBehavior

	-- Add LHS conditions. First is so we can control what displays in the
	-- combinator's window, second is generic "always-true"
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
end

---Create a combinator from a real Thing.
---@param thing things.ThingSummary
local function create_combinator(thing)
	local comb = Combinator:new(thing)
	comb.mode = (thing.tags or EMPTY).mode or "unknown" --[[@as string]]
	clear_combinator_outputs(thing.entity)
	events.raise("cs2.combinator_created", comb)
	events.raise("cs2.combinator_status_changed", comb)
	cs2.raise_combinator_created(comb)
end

---@param comb Cybersyn.Combinator
local function destroy_combinator(comb)
	comb.is_being_destroyed = true
	events.raise("cs2.combinator_destroyed", comb)
	cs2.raise_combinator_destroyed(comb, false)
	comb:destroy_state()
end

events.bind(
	"cybersyn2-combinator-on_initialized",
	---@param ev things.EventData.on_initialized
	function(ev)
		if ev.status == "real" then create_combinator(ev) end
	end
)

events.bind(
	"cybersyn2-combinator-on_status",
	---@param ev things.EventData.on_status
	function(ev)
		local comb = cs2.get_combinator(ev.thing.id, true)
		if not comb then
			if ev.new_status == "real" then
				-- Create new combinator
				create_combinator(ev.thing)
			end
			return
		end

		if ev.new_status == "real" then
			comb.entity = ev.thing.entity
		else
			comb.entity = nil
		end

		local settings = cs2.CombinatorSettings:new(comb, ev.thing)
		events.raise("cs2.combinator_status_changed", comb, settings)

		if ev.new_status == "void" or ev.new_status == "destroyed" then
			destroy_combinator(comb)
		end
	end
)

--------------------------------------------------------------------------------
-- Blueprinting combinators
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- Combinator hotwiring
--------------------------------------------------------------------------------

---@param combinator Cybersyn.Combinator
local function hotwire_combinator(combinator) return combinator:hotwire() end
events.bind("cs2.combinator_status_changed", hotwire_combinator)
events.bind("cs2.combinator_settings_changed", function(combinator, setting)
	if setting == "mode" or setting == nil then hotwire_combinator(combinator) end
end)

--------------------------------------------------------------------------------
-- Reset
--------------------------------------------------------------------------------

events.bind("on_startup", function(reset_data)
	-- Recreate all combinators in the world.
	for _, surface in pairs(game.surfaces) do
		for _, comb_entity in
			pairs(surface.find_entities_filtered({ name = COMBINATOR_NAME }))
		do
			local _, thing = remote.call("things", "get", comb_entity)
			if not thing then
				error(
					"Referential integrity failure: no matching Thing for combinator "
						.. comb_entity.unit_number
				)
			end
			local combinator = cs2.get_combinator(thing.id, true)
			if not combinator and thing.status == "real" then
				create_combinator(thing)
			end
		end
	end
end)
