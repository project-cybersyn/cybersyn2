--------------------------------------------------------------------------------
-- Inventory abstraction
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local tlib = require("lib.core.table")
local counters = require("lib.core.counters")
local signal_keys = require("lib.signal")
local thread = require("lib.core.thread")
local cs2 = _G.cs2
local strace = require("lib.core.strace")

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
local empty = tlib.EMPTY
local table_add = tlib.vector_add
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

---@param item SignalKey
---@param inflow_comp boolean? If `true`, inflows are added to the inventory counts
---@param outflow_comp boolean? If `true`, outflows are subtracted from the inventory counts
---@return int qty Quantity of the given item in the inventory net of given flows
function Inventory:qty(item, inflow_comp, outflow_comp)
	local inv = self.inventory or empty
	local outflow = outflow_comp and (self.outflow or empty) or empty
	local inflow = inflow_comp and (self.inflow or empty) or empty
	return max((inv[item] or 0) - (outflow[item] or 0) + (inflow[item] or 0), 0)
end

function Inventory:clear()
	self.inventory = {}
	self.inflow = {}
	self.inflow_rebate = nil
	self.outflow = {}
	self.outflow_rebate = nil
end

---Determine if this inventory is volatile. A volatile inventory is one whose
---value cannot be correctly read from current combinator state because of
---unreliable data. An example of this is a train stop inventory while a train
---is parked and loading or unloading, in which case the inventory measured
---at the combinators will be wrong until the train completes the delivery.
---@param workload Core.Thread.Workload?
---@return boolean
function Inventory:is_volatile(workload) return false end

---Attempt to update the inventory using best available data. Does nothing
---when inventory is volatile.
---@param workload Core.Thread.Workload?
---@param reread boolean `true` if the inventory's base data should be reread immediately from combinators. `false` if cached combinator reads should be used.
---@return boolean #`true` if the inventory was updated.
function Inventory:update(workload, reread) return false end

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

---@param controlling_stop Cybersyn.TrainStop
---@param slaves Cybersyn.TrainStop[]|nil
function StopInventory:is_volatile(controlling_stop, slaves)
	if controlling_stop.entity.get_stopped_train() then return true end

	if slaves then
		-- A master inventory is volatile if any of its slaves has a parked train
		for _, slave in pairs(slaves) do
			if slave.entity.get_stopped_train() then return true end
		end
	end

	return false
end

---@param controlling_stop Cybersyn.TrainStop
---@param slaves Cybersyn.TrainStop[]|nil
local function stop_inventory_is_volatile(controlling_stop, slaves)
	if controlling_stop.entity.get_stopped_train() then return true end

	if slaves then
		-- A master inventory is volatile if any of its slaves has a parked train
		for _, slave in pairs(slaves) do
			if slave.entity.get_stopped_train() then return true end
		end
	end

	return false
end

function StopInventory:update(workload, reread)
	add_workload(workload, 1)
	local stop = cs2.get_stop(self.created_for_node_id, true)
	if not stop then return false end
	if stop.shared_inventory_master then
		strace.warn(
			"Attempted to update a shared inventory slave's inventory directly. This should only be done from the master stop."
		)
		return false
	end
	local slaves = nil
	if stop.is_master then
		add_workload(workload, 2)
		slaves = stop:get_slaves()
	end

	if stop_inventory_is_volatile(stop, slaves) then return false end

	-- Reread inv combs
	if reread then
		local master_station_comb = stop:read_inventory_combinator_inputs(workload)
		-- Set base from station comb primary wire
		if master_station_comb then
			local primary_wire = master_station_comb:get_primary_wire()
			if primary_wire == "green" then
				self:set_base(master_station_comb.green_inputs)
				if workload then
					add_workload(workload, table_size(master_station_comb.green_inputs))
				end
			else
				self:set_base(master_station_comb.red_inputs)
				if workload then
					add_workload(workload, table_size(master_station_comb.red_inputs))
				end
			end
		end

		-- Reread slave combs
		if slaves then
			for _, slave in pairs(slaves) do
				slave:read_inventory_combinator_inputs(workload)
			end
		end
	end

	-- Reread orders
	for _, order in pairs(self.orders) do
		order:read(workload)
	end

	return true
end

---Append a set of Orders for the given master inventory to the given order
---array.
---@param orders Cybersyn.Order[] The array to which orders will be appended.
---@param master_stop Cybersyn.TrainStop The stop controlling the content of the orders.
---@param target_stop? Cybersyn.TrainStop The stop that will be targeted by trains filling the orders. Used by shared inventory order cloning.
function StopInventory:append_orders(orders, master_stop, target_stop)
	if target_stop == nil then target_stop = master_stop end

	for _, comb in cs2.iterate_combinators(master_stop) do
		if comb.mode == "station" then
			-- Opposite wire on station comb treated as an order.
			local primary_wire = comb:get_primary_wire()
			local opposite_wire = primary_wire == "green" and "red" or "green"
			orders[#orders + 1] =
				Order:new(self, target_stop.id, "primary", comb.id, opposite_wire)
		elseif comb.mode == "inventory" then
			-- Both wires on inventory comb treated as orders.
			orders[#orders + 1] =
				Order:new(self, target_stop.id, "primary", comb.id, "red")
			orders[#orders + 1] =
				Order:new(self, target_stop.id, "secondary", comb.id, "green")
		end
	end
	return orders
end

---Destroy and rebuild all orders for this inventory.
---@param workload Core.Thread.Workload?
function StopInventory:rebuild_orders(workload)
	local master_stop = cs2.get_stop(self.created_for_node_id)
	if not master_stop then return end
	self.orders = self:append_orders({}, master_stop)

	-- Master stop must also generate all orders for slaves.
	if master_stop.is_master then
		for _, slave in pairs(master_stop:get_slaves()) do
			local slave_station = slave:get_combinator_with_mode("station")
			if slave_station then
				if slave_station:get_shared_inventory_independent_orders() then
					self:append_orders(self.orders, slave, slave)
				else
					self:append_orders(self.orders, master_stop, slave)
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

-- Destroy autocreated inventories when their nodes are destroyed.
cs2.on_node_destroyed(function(node)
	local inv = cs2.get_inventory(node.created_inventory_id)
	if inv then inv:destroy() end
end)
