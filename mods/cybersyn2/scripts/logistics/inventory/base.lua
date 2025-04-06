--------------------------------------------------------------------------------
-- Inventory abstraction
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local counters = require("__cybersyn2__.lib.counters")
local signal_keys = require("__cybersyn2__.lib.signal")
local DeliveryState = require("__cybersyn2__.lib.types").DeliveryState
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

local ToSource = DeliveryState.ToSource
local Loading = DeliveryState.Loading
local ToDestination = DeliveryState.ToDestination
local Unloading = DeliveryState.Unloading
local Completed = DeliveryState.Completed
local Failed = DeliveryState.Failed

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
		produce = {},
		consume = {},
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

---Recompute net inventory by adding flows to base.
function Inventory:recompute_net()
	-- If no flow, net = base.
	if (not self.flow) or (not next(self.flow)) then
		self.flow = nil
		self.net_produce = nil
		self.net_consume = nil
		return
	end
	local flow = self.flow --[[@as SignalCounts]]

	-- Compute net produce
	local produce = self.produce
	local net_produce = nil
	if next(produce) then
		net_produce = {}
		for key, count in pairs(produce) do
			local net = count + min(flow[key] or 0, 0)
			if net > 0 then net_produce[key] = net end
		end
	end
	self.net_produce = net_produce

	-- Compute net consume
	local consume = self.consume
	local net_consume = nil
	if next(consume) then
		net_consume = {}
		for key, count in pairs(consume) do
			local net = count + max(flow[key] or 0, 0)
			if net < 0 then net_consume[key] = net end
		end
	end
	self.net_consume = net_consume
end

---Set the core produce/consume data of this inventory from signal values obtained
---by polling live Factorio data.
---@param signals SignalCounts
---@param is_consumer boolean Process consumes (negative inventory)
---@param is_producer boolean Process produces (positive inventory)
function Inventory:set_base_inventory(signals, is_consumer, is_producer)
	local produce = {}
	local consume = {}

	for k, count in pairs(signals) do
		if key_is_cargo(k) then
			if count > 0 and is_producer then
				produce[k] = count
			elseif count < 0 and is_consumer then
				consume[k] = count
			end
		end
	end

	self.produce = produce
	self.consume = consume
	self:recompute_net()
end

---Add the given counts to the current flow of this inventory.
---@param added_flow SignalCounts
---@param sign int 1 to add the flow, -1 to subtract it.
function Inventory:add_flow(added_flow, sign)
	local flow = self.flow or {}
	local produce = self.produce
	local consume = self.consume
	local net_produce = self.net_produce
	local net_consume = self.net_consume

	for key, count in pairs(added_flow) do
		local new_flow = (flow[key] or 0) + sign * count
		if new_flow == 0 then
			flow[key] = nil
		else
			flow[key] = new_flow
		end
		-- Update net produce and consume entries.
		local p_count = produce[key]
		if p_count then
			if not net_produce then
				net_produce = {}
				self.net_produce = net_produce
			end
			local net = p_count + new_flow
			net_produce[key] = max(net, 0)
		end
		local r_count = consume[key]
		if r_count then
			if not net_consume then
				net_consume = {}
				self.net_consume = net_consume
			end
			local net = r_count + new_flow
			net_consume[key] = min(net, 0)
		end
	end

	if next(flow) then
		self.flow = flow
	else
		self.flow = nil
		self.net_produce = nil
		self.net_consume = nil
	end
end

---Get the net produces of this inventory. This is a READ-ONLY cached table
---that should not be retained beyond the current tick.
---@return SignalCounts
function Inventory:get_net_produce() return self.net_produce or self.produce end

---Get the net consumes of this inventory. This is a READ-ONLY cached table
---that should not be retained beyond the current tick.
---@return SignalCounts
function Inventory:get_net_consume() return self.net_consume or self.consume end

---@return SignalCounts produce
---@return SignalCounts consume
---@return SignalCounts? flow
function Inventory:get_inventory_info()
	return self.net_produce or self.produce,
		self.net_consume or self.consume,
		self.flow
end

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

cs2.on_delivery_state_changed(function(delivery, new_state, old_state)
	-- TODO: charge inventories based on delivery states
end)
