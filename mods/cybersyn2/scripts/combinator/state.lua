--------------------------------------------------------------------------------
-- Combinator state management.
-- State represents transient information per comb that should not be stored in
-- settings/blueprints.
--------------------------------------------------------------------------------

local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local inventory_api = _G.cs2.inventory_api
local Node = _G.cs2.Node

local strace = stlib.strace
local TRACE = stlib.TRACE
local WARN = stlib.WARN

---@param combinator Cybersyn.Combinator
local function read_inventory(combinator)
	-- TODO: shared inventory etc.

	if combinator.mode ~= "station" then return end
	local stop = Node.get(combinator.node_id)
	if not stop or (not stop.type == "stop") then return end
	---@cast stop Cybersyn.TrainStop
	if stop.entity.get_stopped_train() then
		-- If a train is at a stop while reading its inventory combinator, read
		-- must be treated as unreliable.
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
