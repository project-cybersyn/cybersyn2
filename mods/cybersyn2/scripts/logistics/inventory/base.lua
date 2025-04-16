--------------------------------------------------------------------------------
-- Inventory abstraction
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local tlib = require("__cybersyn2__.lib.table")
local counters = require("__cybersyn2__.lib.counters")
local signal_keys = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2

-- TODO: This code is called in high performance dispatch loops. Take some
-- care to microoptimize here.

local next = _G.next
local pairs = _G.pairs
local signal_to_key = signal_keys.signal_to_key
local key_is_cargo = signal_keys.key_is_cargo
local min = math.min
local max = math.max
local assign = tlib.assign
local empty = tlib.empty

---@class Cybersyn.Inventory
local Inventory = class("Inventory")
_G.cs2.Inventory = Inventory

---Create a new inventory.
function Inventory:new()
	local id = counters.next("inventory")

	storage.inventories[id] = setmetatable({
		id = id --[[@as Id]],
		inventory = {},
		inflow = {},
		outflow = {},
	}, self)
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

	-- Rebuild base
	for k, count in pairs(counts) do
		if key_is_cargo(k) then base[k] = count end
	end
end

---@param counts SignalCounts
---@param sign number 1 to add the inflow, -1 to subtract it
function Inventory:add_inflow(counts, sign)
	local inflow = self.inflow

	for k, count in pairs(counts) do
		local new_inflow = (inflow[k] or 0) + sign * count
		if new_inflow <= 0 then
			inflow[k] = nil
		else
			inflow[k] = new_inflow
		end
	end
end

---@param counts SignalCounts
---@param sign number 1 to add the outflow, -1 to subtract it
function Inventory:add_outflow(counts, sign)
	local outflow = self.outflow

	for k, count in pairs(counts) do
		local new_outflow = (outflow[k] or 0) + sign * count
		if new_outflow <= 0 then
			outflow[k] = nil
		else
			outflow[k] = new_outflow
		end
	end
end

---Get amount of the given item provided by this Inventory.
function Inventory:get_provided_qty(item) return 0 end

---Get the amount of the given item pulled by this Inventory.
function Inventory:get_pulled_qty(item) return 0 end

function Inventory:get_pushed_qty(item) return 0 end

function Inventory:get_sink_qty(item) return 0 end

---Iterate over items this inventory could conceivably produce.
---@param f fun(item: SignalKey, provide_qty: integer, push_qty: integer)
function Inventory:foreach_producible_item(f) end

---Iterate over items this inventory could conceivably consume.
---@param f fun(item: SignalKey, pull_qty: integer, sink_qty: integer)
function Inventory:foreach_consumable_item(f) end

---Set pulls for this inventory.
---@param counts SignalCounts
function Inventory:set_pulls(counts) end

---Set push thresholds for this inventory.
---@param counts SignalCounts
function Inventory:set_pushes(counts) end

---Set sink thresholds for this inventory.
---@param counts SignalCounts
function Inventory:set_sinks(counts) end

--------------------------------------------------------------------------------
-- Pseudoinventory
--------------------------------------------------------------------------------

---A pseudoinventory is an inventory that can have negative base content
---representing requests.
---@class Cybersyn.Pseudoinventory: Cybersyn.Inventory
local Pseudoinventory = class("Pseudoinventory", Inventory)
_G.cs2.Pseudoinventory = Pseudoinventory

function Pseudoinventory:get_provided_qty(item)
	local inv = self.inventory
	local of = self.outflow
	return max((inv[item] or 0) - (of[item] or 0), 0)
end

function Pseudoinventory:get_pulled_qty(item)
	local inv = self.inventory
	local inf = self.inflow
	return max(-((inv[item] or 0) + (inf[item] or 0)), 0)
end

function Pseudoinventory:foreach_producible_item(f)
	local inv = self.inventory
	local of = self.outflow
	for item, qty in pairs(inv) do
		local net = max(qty - (of[item] or 0), 0)
		if net > 0 then f(item, net, 0) end
	end
end

function Pseudoinventory:foreach_consumable_item(f)
	local inv = self.inventory
	local inf = self.inflow
	for item, qty in pairs(inv) do
		local net = max(-(qty + (inf[item] or 0)), 0)
		if net > 0 then f(item, net, 0) end
	end
end

--------------------------------------------------------------------------------
-- TrueInventory
--------------------------------------------------------------------------------

---A true inventory is an inventory that can only have positive base content
---representing actual inventory. Requests and thresholds are set separately.
---@class Cybersyn.TrueInventory: Cybersyn.Inventory
---@field public provides SignalCounts?
---@field public pulls SignalCounts?
---@field public pushes SignalCounts?
---@field public sinks SignalCounts?
local TrueInventory = class("TrueInventory", Inventory)
_G.cs2.TrueInventory = TrueInventory

function TrueInventory:set_pulls(counts)
	local pulls = {}
	self.pulls = pulls
	for k, count in pairs(counts) do
		if key_is_cargo(k) then self.pulls[k] = count end
	end
end

function TrueInventory:set_pushes(counts)
	local pushes = {}
	self.pushes = pushes
	for k, count in pairs(counts) do
		if key_is_cargo(k) then self.pushes[k] = count end
	end
end

function TrueInventory:set_sinks(counts)
	local sinks = {}
	self.sinks = sinks
	for k, count in pairs(counts) do
		if key_is_cargo(k) then self.sinks[k] = count end
	end
end

function TrueInventory:get_provided_qty(item)
	local inv = self.inventory
	local of = self.outflow
	return max((inv[item] or 0) - (of[item] or 0), 0)
end

function TrueInventory:get_pulled_qty(item)
	local pulls = self.pulls
	if not pulls then return 0 end
	local inv = self.inventory
	local inf = self.inflow
	return max((pulls[item] or 0) - ((inv[item] or 0) + (inf[item] or 0)), 0)
end

function TrueInventory:get_pushed_qty(item)
	local pushes = self.pushes
	if not pushes then return 0 end
	local inv = self.inventory
	local of = self.outflow

	return max(((inv[item] or 0) - (of[item] or 0)) - (pushes[item] or 0), 0)
end

function TrueInventory:get_sink_qty(item)
	local sinks = self.sinks
	if not sinks then return 0 end
	local inv = self.inventory
	local inf = self.inflow
	return max((sinks[item] or 0) - ((inv[item] or 0) + (inf[item] or 0)), 0)
end

function TrueInventory:foreach_producible_item(f)
	local inv = self.inventory
	local of = self.outflow
	local pushes = self.pushes or empty
	for item, qty in pairs(inv) do
		local net = max(qty - (of[item] or 0), 0)
		local pushed = max(net - pushes[item], 0)
		if net > 0 or pushed > 0 then f(item, net, pushed) end
	end
end

function TrueInventory:foreach_consumable_item(f)
	local inv = self.inventory
	local inf = self.inflow
	local pulls = self.pulls or empty
	local sinks = self.sinks or empty

	for item, qty in pairs(pulls) do
		local net = (inv[item] or 0) + (inf[item] or 0)
		local pulled = max(qty - net, 0)
		local sunk = max((sinks[item] or 0) - net, 0)
		if pulled > 0 or sunk > 0 then f(item, pulled, sunk) end
	end
	for item, qty in pairs(sinks) do
		if not pulls[item] then
			local net = (inv[item] or 0) + (inf[item] or 0)
			local sunk = max(qty - net, 0)
			if sunk > 0 then f(item, 0, sunk) end
		end
	end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- Automatically create inventories for train stops.
cs2.on_node_created(function(node)
	if node.type == "stop" then
		---@cast node Cybersyn.TrainStop
		local inv = Pseudoinventory:new()
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
