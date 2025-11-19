--------------------------------------------------------------------------------
-- Inventory abstraction
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local tlib = require("lib.core.table")
local counters = require("lib.core.counters")
local signal_keys = require("lib.signal")
local thread = require("lib.core.thread")
local cs2 = _G.cs2

-- TODO: This code is called in high performance dispatch loops. Take some
-- care to microoptimize here.

local next = _G.next
local pairs = _G.pairs
local signal_to_key = signal_keys.signal_to_key
local key_to_signal = signal_keys.key_to_signal
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
local combinator_settings = _G.cs2.combinator_settings
local mod_settings = _G.cs2.mod_settings
local Order = _G.cs2.Order
local add_workload = thread.add_workload
local table_size = _G.table_size

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
		last_consumed_tick = {},
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

---@param inflow_comp boolean? If `true`, inflows are added to the inventory counts.
---@param outflow_comp boolean? If `true`, outflows are subtracted from the inventory counts.
---@param workload Core.Thread.Workload?
---@return SignalCounts net Inventory net of given flows
function Inventory:net(inflow_comp, outflow_comp, workload)
	local inv = self.inventory or empty
	local outflow = outflow_comp and (self.outflow or empty) or empty
	local inflow = inflow_comp and (self.inflow or empty) or empty
	local net_inventory = {}

	for key, count in pairs(inv) do
		local real = count - (outflow[key] or 0) + (inflow[key] or 0)
		if real > 0 then net_inventory[key] = real end
	end
	if workload then add_workload(workload, table_size(inv)) end

	for key, count in pairs(inflow) do
		if not inv[key] then
			if count > 0 then net_inventory[key] = count end
		end
	end
	if workload then add_workload(workload, table_size(inflow)) end

	return net_inventory
end

---Compute used capacity of this inventory, in stacks (for items) and units
---(for fluids).
---@return uint used_item_stack_capacity
---@return uint used_fluid_capacity
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
---@param workload Core.Thread.Workload?
---@param reread boolean `true` if the inventory's base data should be reread immediately from combinators. `false` if cached combinator reads should be used.
---@return boolean #`true` if the inventory was updated.
function Inventory:update(workload, reread) return false end

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

function StopInventory:update(workload, reread)
	add_workload(workload, 1)
	if self:is_volatile() then return false end
	local stop = cs2.get_stop(self.created_for_node_id, true)
	if not stop then return false end

	-- Reread inv combs
	if reread then
		for combinator_id in pairs(stop.combinator_set) do
			local comb = cs2.get_combinator(combinator_id, true)
			if comb then
				local mode = comb.mode
				if mode == "inventory" then
					comb:read_inputs()
					add_workload(workload, 5)
				elseif mode == "station" then
					comb:read_inputs()
					add_workload(workload, 5)
					local primary_wire = comb:get_primary_wire()
					if primary_wire == "green" then
						self:set_base(comb.green_inputs)
						if workload then
							add_workload(workload, table_size(comb.green_inputs))
						end
					else
						self:set_base(comb.red_inputs)
						if workload then
							add_workload(workload, table_size(comb.red_inputs))
						end
					end
				end
			end
		end
	end

	-- Reread orders
	for _, order in pairs(self.orders) do
		-- XXX: this if is only here to prevent a crash during Alpha.
		if order.read then order:read(workload) end
	end

	return true
end

---Destroy and rebuild all orders for this inventory.
function StopInventory:rebuild_orders()
	---@type Cybersyn.Order[]
	local orders = {}
	self.orders = orders
	local controlling_stop = cs2.get_stop(self.created_for_node_id)
	if not controlling_stop then return end

	for _, comb in cs2.iterate_combinators(controlling_stop) do
		if comb.mode == "station" then
			-- Opposite wire on station comb treated as an order.
			local primary_wire = comb:get_primary_wire()
			local opposite_wire = primary_wire == "green" and "red" or "green"
			orders[#orders + 1] =
				Order:new(self, controlling_stop.id, "primary", comb.id, opposite_wire)
		elseif comb.mode == "inventory" then
			-- Both wires on inventory comb treated as orders.
			orders[#orders + 1] =
				Order:new(self, controlling_stop.id, "primary", comb.id, "red")

			orders[#orders + 1] =
				Order:new(self, controlling_stop.id, "secondary", comb.id, "green")
		end
	end

	-- Copy orders for slaves
	-- TODO: Fix shared inventory.
	if controlling_stop.shared_inventory_slaves then
		local n_orders_to_copy = #orders
		for slave_id in pairs(controlling_stop.shared_inventory_slaves) do
			local slave = cs2.get_stop(slave_id)
			if slave then
				for i = 1, n_orders_to_copy do
					local old_order = orders[i]
					local new_order = assign({}, old_order) --[[@as Cybersyn.Order]]
					new_order.node_id = slave.id
					orders[#orders + 1] = new_order
				end
			end
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
