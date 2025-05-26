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
local key_to_stacksize = signal_keys.key_to_stacksize
local key_is_cargo = signal_keys.key_is_cargo
local key_is_fluid = signal_keys.key_is_fluid
local classify_key = signal_keys.classify_key
local min = math.min
local max = math.max
local ceil = math.ceil
local assign = tlib.assign
local empty = tlib.empty
local table_add = tlib.vector_add

---@param base table<string,int>
---@param addend table<string,int>
---@param sign int
local function table_add_positive(base, addend, sign)
	for k, v in pairs(addend) do
		local net = (base[k] or 0) + sign * v
		if net > 0 then
			base[k] = net
		else
			base[k] = nil
		end
	end
end

---@class Cybersyn.Inventory
---@field public inflow_rebate SignalCounts? Amount to be refunded to inflows during next base inventory update.
---@field public outflow_rebate SignalCounts? Amount to be refunded to outflows during next base inventory update.
---@field public used_item_stack_capacity uint? Cached value of used item stack capacity.
---@field public used_fluid_capacity uint? Cached value of used fluid capacity.
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
		orders = {},
	}, self)
	local inv = storage.inventories[id]

	return inv
end

---Get an inventory by ID.
---@param inventory_id Id?
---@return Cybersyn.Inventory?
local function get_inventory(inventory_id)
	return storage.inventories[inventory_id or ""]
end
Inventory.get = get_inventory
_G.cs2.get_inventory = get_inventory

function Inventory:destroy()
	cs2.raise_inventory_destroyed(self)
	storage.inventories[self.id] = nil
end

---Set base inventory from raw signal counts. Signals will be filtered for
---cargo validity.
---@param counts SignalCounts|nil
function Inventory:set_base(counts)
	-- Rebate flows
	if self.inflow_rebate then
		self:add_inflow(self.inflow_rebate, 1)
		self.inflow_rebate = nil
	end

	if self.outflow_rebate then
		self:add_outflow(self.outflow_rebate, 1)
		self.outflow_rebate = nil
	end

	if counts then
		-- Rebuild base
		local base = {}
		self.inventory = base
		for k, count in pairs(counts) do
			if key_is_cargo(k) then base[k] = count end
		end
		-- Clear cached
		self.used_fluid_capacity = nil
		self.used_item_stack_capacity = nil
	else
		if next(self.inventory) then
			-- Clear base
			self.inventory = {}
			-- Clear cached
			self.used_fluid_capacity = nil
			self.used_item_stack_capacity = nil
		end
	end
end

---@param counts SignalCounts
---@param sign number
function Inventory:add_inflow(counts, sign)
	self.used_fluid_capacity = nil
	self.used_item_stack_capacity = nil
	return table_add_positive(self.inflow, counts, sign)
end

---@param counts SignalCounts
---@param sign number
function Inventory:add_inflow_rebate(counts, sign)
	if not self.inflow_rebate then self.inflow_rebate = {} end
	return table_add(self.inflow_rebate, sign, counts)
end

---@param item SignalKey
---@param qty int
function Inventory:add_single_item_inflow(item, qty)
	self.used_fluid_capacity = nil
	self.used_item_stack_capacity = nil
	local inflow = self.inflow
	local new_inflow = (inflow[item] or 0) + qty
	if new_inflow <= 0 then
		inflow[item] = nil
	else
		inflow[item] = new_inflow
	end
end

---@param counts SignalCounts
---@param sign number
function Inventory:add_outflow(counts, sign)
	return table_add_positive(self.outflow, counts, sign)
end

---@param counts SignalCounts
---@param sign number
function Inventory:add_outflow_rebate(counts, sign)
	if not self.outflow_rebate then self.outflow_rebate = {} end
	return table_add(self.outflow_rebate, sign, counts)
end

---@param item SignalKey
---@param qty int
function Inventory:add_single_item_outflow(item, qty)
	local outflow = self.outflow
	local new_outflow = (outflow[item] or 0) + qty
	if new_outflow <= 0 then
		outflow[item] = nil
	else
		outflow[item] = new_outflow
	end
end

---Compute used capacity of this inventory, in stacks (for items) and units
---(for fluids).
---@return uint
---@return uint
function Inventory:get_used_capacities()
	if self.used_item_stack_capacity then
		return self.used_item_stack_capacity, self.used_fluid_capacity
	end

	local used_item_stack_capacity = 0
	local used_fluid_capacity = 0
	local base = self.inventory or empty
	local inflow = self.inflow or empty

	for k, v in pairs(base) do
		local net = v + (inflow[k] or 0)

		if key_is_fluid(k) then
			used_fluid_capacity = used_fluid_capacity + net
		else
			local ss = key_to_stacksize(k)
			if ss and ss > 0 then
				used_item_stack_capacity = used_item_stack_capacity + ceil(net / ss)
			end
		end
	end
	for k, v in pairs(inflow) do
		if not base[k] then
			if key_is_fluid(k) then
				used_fluid_capacity = used_fluid_capacity + v
			else
				local ss = key_to_stacksize(k)
				if ss and ss > 0 then
					used_item_stack_capacity = used_item_stack_capacity + ceil(v / ss)
				end
			end
		end
	end

	self.used_item_stack_capacity = used_item_stack_capacity
	self.used_fluid_capacity = used_fluid_capacity

	return used_item_stack_capacity, used_fluid_capacity
end

---@param item_stack_capacity uint|nil
---@param fluid_capacity uint|nil
function Inventory:set_capacities(item_stack_capacity, fluid_capacity)
	self.item_stack_capacity = item_stack_capacity
	self.fluid_capacity = fluid_capacity
end

function Inventory:get_capacities()
	return self.item_stack_capacity, self.fluid_capacity
end

function Inventory:clear()
	self.inventory = {}
	self.inflow = {}
	self.inflow_rebate = nil
	self.outflow = {}
	self.outflow_rebate = nil
	self.item_stack_capacity = nil
	self.fluid_capacity = nil
	self.used_item_stack_capacity = nil
	self.used_fluid_capacity = nil
end

---Determine if this inventory is volatile. A volatile inventory is one whose
---value cannot be correctly read from current combinator state because of
---unreliable data. An example of this is a train stop inventory while a train
---is parked and loading or unloading, in which case the inventory measured
---at the combinators will be wrong until the train completes the delivery.
---@return boolean
function Inventory:is_volatile() return false end

---Attempt to update the inventory using best available data. Does nothing
---when inventory is volatile.
---@param reread boolean `true` if the inventory's base data should be reread immediately from combinators. `false` if cached combinator reads should be used.
---@return boolean #`true` if the inventory was updated.
function Inventory:update(reread) return false end

--------------------------------------------------------------------------------
-- Fast inventory accessors
--------------------------------------------------------------------------------

---@param inventory Cybersyn.Inventory
---@param item SignalKey
function _G.cs2.inventory_avail_qty(inventory, item)
	return max(
		(inventory.inventory[item] or 0) - (inventory.outflow[item] or 0),
		0
	)
end

---@param order Cybersyn.Order
---@param item SignalKey
function _G.cs2.order_provided_qty(order, item)
	local inv = order.inventory
	local base = min(order.provides[item] or 0, inv.inventory[item] or 0)
	return max(base - (inv.outflow[item] or 0), 0)
end

---@param order Cybersyn.Order
---@param item SignalKey
function _G.cs2.order_requested_qty(order, item)
	local inv = order.inventory
	local deficit = (order.requests[item] or 0)
		- (inv.inventory[item] or 0)
		- (inv.inflow[item] or 0)
	return max(deficit, 0)
end

--------------------------------------------------------------------------------
-- StopInventory
--------------------------------------------------------------------------------

---Inventory associated with a train stop.
---@class Cybersyn.StopInventory: Cybersyn.Inventory
local StopInventory = class("StopInventory", Inventory)
_G.cs2.StopInventory = StopInventory

function StopInventory:new()
	local inv = Inventory.new(self)
	return inv --[[@as Cybersyn.StopInventory]]
end

function StopInventory:is_volatile()
	local controlling_stop = cs2.get_stop(self.created_for_node_id)
	if not controlling_stop then
		error(
			"StopInventory without associated controlling stop, should be impossible"
		)
	end

	if controlling_stop.shared_inventory_slaves then
		-- A shared inventory is volatile if any of its slaves has a parked train
		for slave_id in pairs(controlling_stop.shared_inventory_slaves) do
			local slave = cs2.get_stop(slave_id)
			if slave and slave.entity.get_stopped_train() then return true end
		end
		return not not controlling_stop.entity.get_stopped_train()
	else
		return not not controlling_stop.entity.get_stopped_train()
	end
end

function StopInventory:update(reread)
	if self:is_volatile() then return false end
	for _, order in pairs(self.orders) do
		local stop = cs2.get_stop(order.node_id, true)
		if not stop then return false end
		-- Clear existing order
		if next(order.requests) then order.requests = {} end
		if next(order.provides) then order.provides = {} end
		if next(order.networks) then order.networks = {} end
		if next(order.thresholds_in) then order.thresholds_in = {} end
		if next(order.thresholds_out) then order.thresholds_out = {} end
		order.priority = stop.priority or 0
		order.request_all = nil
		-- Copy stop data
		-- TODO: move last_consumed_tick to inventory
		order.last_consumed_tick = stop.last_consumed_tick or {}
		-- TODO: tekbox equation?
		order.busy_value = stop:get_occupancy()

		-- Rebuild order from its governing combinator
		local comb = cs2.get_combinator(order.combinator_id, true)
		if comb then
			if reread then comb:read_inputs() end
			if comb.mode == "station" then
				-- Red wire of station = true inventory/control signals
				self:set_base(comb.red_inputs)
			end
			local inputs = order.combinator_input == "green" and comb.green_inputs
				or comb.red_inputs
			for signal_key, count in pairs(inputs or empty) do
				local genus = classify_key(signal_key)
				if genus == "cargo" then
					if count < 0 then
						order.requests[signal_key] = -count
						order.thresholds_in[signal_key] =
							stop:get_inbound_threshold(signal_key)
					elseif count > 0 then
						order.provides[signal_key] = count
						order.thresholds_out[signal_key] =
							stop:get_outbound_threshold(signal_key)
					end
				elseif genus == "virtual" then
					if signal_key == "cybersyn2-priority" then
						order.priority = count
					elseif signal_key == "cybersyn2-all-items" and count < 0 then
						order.request_all = true
					elseif cs2.CONFIGURATION_VIRTUAL_SIGNAL_SET[signal_key] then
						-- no CS2 config signals as networks
					else
						order.networks[signal_key] = true
					end
				end
			end
			-- Default network if no networks are set.
			if not next(order.networks) and stop.default_networks then
				order.networks = stop.default_networks
			end
		else
			-- Order has no governing combinator.
		end
	end
	return true
end

---@param inv Cybersyn.Inventory
---@param comb_id Id
---@param node_id Id
---@param comb_input "green"|"red"
local function create_blank_order(inv, comb_id, node_id, comb_input)
	---@type Cybersyn.Order
	local order = {
		inventory = inv,
		combinator_id = comb_id,
		node_id = node_id,
		combinator_input = comb_input,
		requests = {},
		provides = {},
		networks = {},
		thresholds_in = {},
		thresholds_out = {},
		last_consumed_tick = {},
		priority = 0,
		busy_value = 0,
	}
	return order
end

---Destroy and rebuild all orders for this inventory.
function StopInventory:rebuild_orders()
	---@type Cybersyn.Order[]
	local orders = {}
	self.orders = orders
	local controlling_stop = cs2.get_stop(self.created_for_node_id)
	if not controlling_stop then return end
	local station_comb = controlling_stop:get_combinator_with_mode("station")
	if not station_comb then return end
	-- Green-wire order for station combinator
	orders[#orders + 1] =
		create_blank_order(self, station_comb.id, controlling_stop.id, "green")
	-- Green- and red-wire orders for each inventory comb
	local inventory_combs = controlling_stop:get_associated_combinators(
		function(c) return c.mode == "inventory" end
	)
	for _, comb in pairs(inventory_combs) do
		orders[#orders + 1] =
			create_blank_order(self, comb.id, controlling_stop.id, "green")

		orders[#orders + 1] =
			create_blank_order(self, comb.id, controlling_stop.id, "red")
	end
	-- TODO: shared slaves?
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- Automatically create inventories for train stops.
cs2.on_node_created(function(node)
	if node.type == "stop" then
		---@cast node Cybersyn.TrainStop
		local inv = StopInventory:new()
		node.created_inventory_id = inv.id
		inv.created_for_node_id = node.id
		cs2.raise_inventory_created(inv)
		node:set_inventory(inv.id)
	end
end, true)

cs2.on_node_destroyed(function(node)
	local inv = cs2.get_inventory(node.created_inventory_id)
	if inv then inv:destroy() end
end)
