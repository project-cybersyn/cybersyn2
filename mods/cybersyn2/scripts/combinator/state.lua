--------------------------------------------------------------------------------
-- Combinator state management.
-- State represents transient information per comb that should not be stored in
-- settings/blueprints.
--------------------------------------------------------------------------------

local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local stop_api = _G.cs2.stop_api
local inventory_api = _G.cs2.inventory_api

local strace = stlib.strace
local TRACE = stlib.TRACE
local WARN = stlib.WARN

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
		strace(
			TRACE,
			"message",
			"skipped inventory read due to train present",
			stop.entity
		)
		return
	end
	local inventory = inventory_api.get_inventory(stop.inventory_id)
	if not inventory then
		strace(WARN, "message", "stop without an inventory", stop.entity)
		return
	end
	inventory_api.set_base_inventory(
		inventory,
		combinator.inputs or {},
		stop.is_consumer,
		stop.is_producer
	)
end

-- Read inventory of inventory combinators when their inputs are read.
cs2.on_combinator_inputs_read(read_inventory)
