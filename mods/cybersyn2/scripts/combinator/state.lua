--------------------------------------------------------------------------------
-- Combinator state management.
-- State represents transient information per comb that should not be stored in
-- settings/blueprints.
--------------------------------------------------------------------------------

local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local Node = _G.cs2.Node
local Inventory = _G.cs2.Inventory

---@class Cybersyn.Combinator
local Combinator = _G.cs2.Combinator

local strace = stlib.strace
local TRACE = stlib.TRACE
local WARN = stlib.WARN

---Update the inventory associated with this combinator using the most recently
---polled input values.
---@param force boolean? Force inventory to update regardless of circumstances.
function Combinator:update_inventory(force)
	-- TODO: shared inventory etc.

	if self.mode == "station" then
		local stop = Node.get(self.node_id)
		if not stop or (not stop.type == "stop") then return end
		---@cast stop Cybersyn.TrainStop
		if (not force) and stop.entity.get_stopped_train() then
			-- If a train is at a stop while reading its inventory combinator, read
			-- must be treated as unreliable.
			return
		end
		-- Inventory sent to station combinator goes to stop's created inventory.
		-- (its actual inventory may come from a shared inventory combinator
		-- elsewhere)
		local inventory = Inventory.get(stop.created_inventory_id)
		if not inventory then
			strace(WARN, "message", "stop without an inventory", stop.entity)
			return
		end
		inventory:set_base(self.inputs or {})
	end
end
