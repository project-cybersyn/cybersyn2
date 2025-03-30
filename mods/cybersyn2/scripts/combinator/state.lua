--------------------------------------------------------------------------------
-- Combinator state management.
-- State represents transient information per comb that should not be stored in
-- settings/blueprints.
--------------------------------------------------------------------------------

local signal_lib = require("__cybersyn2__.lib.signal")
local log = require("__cybersyn2__.lib.logging")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local stop_api = _G.cs2.stop_api
local combinator_modes = _G.cs2.combinator_modes
local inventory_api = _G.cs2.inventory_api

local signal_to_key = signal_lib.signal_to_key
local RED_INPUTS = defines.wire_connector_id.circuit_red
local GREEN_INPUTS = defines.wire_connector_id.circuit_green

---@param combinator Cybersyn.Combinator
local function read_inventory(combinator)
	-- TODO: if a train is at a stop while reading an inventory combinator,
	-- the inventory is volatile and the read is unreliable.
	-- If we get a non-volatile read on inventory input for a combinator
	-- implementing an inventory, we should immediately update the inventory while
	-- the reading is as accurate as possible.

	-- TODO: shared inventory etc.

	if combinator.mode ~= "station" then return end
	local stop = stop_api.get_stop(combinator.node_id)
	if not stop then return end
	if stop.entity.get_stopped_train() then
		-- Volatile
		log.trace("skipped inventory read due to train present", stop.entity)
	end
	local inventory = inventory_api.get_inventory(stop.inventory_id)
	if not inventory then
		log.warn("stop without an inventory", stop.entity)
		return
	end
	inventory_api.set_base_inventory(
		inventory,
		combinator.inputs,
		stop.is_consumer,
		stop.is_producer
	)
end

---If the given combinator is in a mode that supports inputs, read and cache
---its current input signals.
---@param combinator Cybersyn.Combinator
function _G.cs2.combinator_api.read_inputs(combinator)
	-- Sanity check
	local mode = combinator.mode or ""
	local mdef = combinator_modes[mode]
	if not mdef or not mdef.is_input then
		combinator.inputs = nil
		return
	end
	local combinator_entity = combinator.entity
	if not combinator_entity or not combinator_entity.valid then return end

	-- Read input sigs
	local signals = combinator_entity.get_signals(RED_INPUTS, GREEN_INPUTS)
	if signals then
		---@type SignalCounts
		local inputs = {}
		for i = 1, #signals do
			local signal = signals[i]
			inputs[signal_to_key(signal.signal)] = signal.count
		end
		combinator.inputs = inputs
	else
		combinator.inputs = nil
	end

	-- Opportunistic inventory reading
	read_inventory(combinator)
end
