--------------------------------------------------------------------------------
-- Inventory abstraction
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local tlib = require("__cybersyn2__.lib.table")
local counters = require("__cybersyn2__.lib.counters")
local signal_keys = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2

-- This code is called in high performance dispatch loops. We will take some
-- care to microoptimize here by using upvalues rather than globals. We will
-- also unroll loops, avoid table lookups, etc.

local next = _G.next
local pairs = _G.pairs
local signal_to_key = signal_keys.signal_to_key
local key_is_cargo = signal_keys.key_is_cargo
local min = math.min
local max = math.max
local assign = tlib.assign

-- Inventory notes:
-- - Don't poll a station while a train is there, because result will be
-- inaccurate.
-- - Poll stations when trains leave.
-- - Allow logistics algorithm to access live polling data.

---@class Cybersyn.Inventory
local Inventory = class("Inventory")
_G.cs2.Inventory = Inventory

---Create a new inventory.
---@return Cybersyn.Inventory
function Inventory.new()
	local id = counters.next("inventory")

	storage.inventories[id] = setmetatable({
		id = id --[[@as Id]],
		inventory = {},
	}, Inventory)
	local inv = storage.inventories[id]
	cs2.raise_inventory_created(inv)
	return inv
end

---Get an inventory by ID.
---@param inventory_id Id?
---@return Cybersyn.Inventory?
function Inventory.get(inventory_id)
	return storage.inventories[inventory_id or ""]
end

function Inventory:destroy()
	cs2.raise_inventory_destroyed(self)
	storage.inventories[self.id] = nil
end

---Set base inventory from raw signal counts. Signals will be filtered for
---cargo validity.
---@param counts SignalCounts
function Inventory:set_base(counts)
	local base = {}
	self.inventory = base
	local inflow = self.inflow
	local outflow = self.outflow

	-- Rebuild base
	for k, count in pairs(counts) do
		if key_is_cargo(k) then base[k] = count end
	end

	-- Rebuild net outflow
	if outflow and next(outflow) then
		local net_outflow = assign({}, base)
		-- Recompute net outflow from base - outflow
		for k, out in pairs(outflow) do
			local nk = (net_outflow[k] or 0) - out
			net_outflow[k] = nk
		end
		self.net_outflow = net_outflow
	else
		self.outflow = nil
		self.net_outflow = nil
	end

	-- Rebuild net inflow
	if inflow and next(inflow) then
		local net_inflow = assign({}, base)
		-- Recompute net inflow from base + inflow
		for k, in_ in pairs(inflow) do
			local nk = (net_inflow[k] or 0) + in_
			net_inflow[k] = nk
		end
		self.net_inflow = net_inflow
	else
		self.inflow = nil
		self.net_inflow = nil
	end
end

---@param counts SignalCounts
---@param sign number 1 to add the inflow, -1 to subtract it
function Inventory:add_inflow(counts, sign)
	local inflow = self.inflow or {}
	local net_inflow = self.net_inflow
	local base = self.inventory

	for k, count in pairs(counts) do
		local new_inflow = (inflow[k] or 0) + sign * count
		if new_inflow <= 0 then
			inflow[k] = nil
			if net_inflow then net_inflow[k] = base[k] or 0 end
		else
			inflow[k] = new_inflow
			local net_inflow_k = (base[k] or 0) + new_inflow
			if not net_inflow then
				net_inflow = {}
				self.net_inflow = net_inflow
			end
			net_inflow[k] = net_inflow_k
		end
	end

	if next(inflow) then
		self.inflow = inflow
	else
		self.inflow = nil
		self.net_inflow = nil
	end
end

---@param counts SignalCounts
---@param sign number 1 to add the outflow, -1 to subtract it
function Inventory:add_outflow(counts, sign)
	local outflow = self.outflow or {}
	local net_outflow = self.net_outflow
	local base = self.inventory

	for k, count in pairs(counts) do
		local new_outflow = (outflow[k] or 0) + sign * count
		if new_outflow <= 0 then
			outflow[k] = nil
			if net_outflow then net_outflow[k] = base[k] or 0 end
		else
			outflow[k] = new_outflow
			local net_outflow_k = (base[k] or 0) - new_outflow
			if not net_outflow then
				net_outflow = {}
				self.net_outflow = net_outflow
			end
			net_outflow[k] = net_outflow_k
		end
	end

	if next(outflow) then
		self.outflow = outflow
	else
		self.outflow = nil
		self.net_outflow = nil
	end
end

---Get the net outflow of this inventory. This is a READ-ONLY cached table
---that should not be retained beyond the current tick.
---@return SignalCounts
function Inventory:get_net_outflow() return self.net_outflow or self.inventory end

---Get the net inflow of this inventory. This is a READ-ONLY cached table
---that should not be retained beyond the current tick.
---@return SignalCounts
function Inventory:get_net_inflow() return self.net_inflow or self.inventory end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- Automatically create inventories for train stops.
-- TODO: shared inventory handling
cs2.on_node_created(function(node)
	if node.type == "stop" then
		---@cast node Cybersyn.TrainStop
		local inv = Inventory.new()
		node.inventory_id = inv.id
		node.created_inventory_id = inv.id
		inv.created_for_node_id = node.id
		inv.surface_index = node.entity.surface_index
	end
end, true)

cs2.on_node_destroyed(function(node)
	local inv = Inventory.get(node.created_inventory_id)
	if inv then inv:destroy() end
end)
