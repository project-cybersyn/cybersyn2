--------------------------------------------------------------------------------
-- Base API for Cybersyn `Node` objects.
--------------------------------------------------------------------------------

local counters = require("__cybersyn2__.lib.counters")
local class = require("__cybersyn2__.lib.class").class
local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local signal = require("__cybersyn2__.lib.signal")
local scheduler = require("__cybersyn2__.lib.scheduler")
local cs2 = _G.cs2
local Inventory = _G.cs2.Inventory
local mod_settings = _G.cs2.mod_settings

local strace = stlib.strace
local ERROR = stlib.ERROR
local band = bit32.band
local pairs = _G.pairs
local key_is_fluid = signal.key_is_fluid
local key_to_stacksize = signal.key_to_stacksize
local Combinator = _G.cs2.Combinator
local empty = tlib.empty

---@class Cybersyn.Node
local Node = class("Node")
_G.cs2.Node = Node

---Create a new node state. No creation events are fired; that is delegated to
---the specific node type's lifecycle management.
function Node.new(type)
	local id = counters.next("node")
	local node = setmetatable({
		id = id,
		type = type or "generic", -- default type
		combinator_set = {},
		created_tick = game.tick,
		last_consumed_tick = {},
		deliveries = {},
		log_size = 20,
		log_current = 1,
		log_buffer = {},
	}, Node)

	storage.nodes[id] = node
	return storage.nodes[id]
end

---Destroy node and state.
function Node:destroy()
	if self.is_being_destroyed then
		strace(
			stlib.WARN,
			"message",
			"Node:destroy() called on already-destroyed node",
			self
		)
		return
	end
	self.is_being_destroyed = true
	cs2.raise_node_destroyed(self)
	-- If type-specific destructors bound to the event failed to clear the
	-- combinator set, we must do so here.
	if next(self.combinator_set) then
		tlib.for_each(self.combinator_set, function(_, combinator_id)
			local combinator = Combinator.get(combinator_id, true)
			Node.disassociate_combinator(combinator, true)
		end)
		cs2.raise_node_combinator_set_changed(self)
	end
	storage.nodes[self.id] = nil
end

---Get a node from storage by id.
---@param id Id?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.Node?
local function get_node(id, skip_validation)
	if not id then return nil end
	local node = storage.nodes[id]
	if skip_validation then
		return node
	else
		return (node and node:is_valid()) and node or nil
	end
end
_G.cs2.get_node = get_node
Node.get = get_node

---Determine if a node is valid.
---@return boolean
function Node:is_valid() return false end

---Associate the given combinator with the given node.
---@param combinator Cybersyn.Combinator Reference to a *valid* combinator.
---@param suppress_set_changed boolean? If `true`, does not raise the `node_combinator_set_changed` event. You must do so yourself if performing a batch of updates.
---@return boolean success `true` if the combinator was successfully associated, `false` if not.
---@return Cybersyn.Node? old_node The node that the combinator was previously associated with, if any.
function Node:associate_combinator(combinator, suppress_set_changed)
	if not self then return false end
	local old_node
	if combinator.node_id and combinator.node_id ~= self.id then
		-- Combinator is already associated with a different node.
		old_node = Node.get(combinator.node_id, true)
		Node.disassociate_combinator(combinator, suppress_set_changed)
	end

	if not self.combinator_set[combinator.id] then
		self.combinator_set[combinator.id] = true
		combinator.node_id = self.id
		cs2.raise_combinator_node_associated(combinator, self, nil)
		if not suppress_set_changed then
			cs2.raise_node_combinator_set_changed(self)
		end
		return true, old_node
	end

	return false, old_node
end

---Disassociate the given combinator from its associated node if any.
---@param combinator Cybersyn.Combinator? Reference to a *valid* combinator.
---@param suppress_set_changed boolean? If `true`, does not raise the `node_combinator_set_changed` event. You must do so yourself if performing a batch of updates.
---@return Cybersyn.Node? old_node If the combinator was disassociated, the node that it was disassociated from, otherwise `nil`.
function Node.disassociate_combinator(combinator, suppress_set_changed)
	if not combinator then return nil end
	local node = Node.get(combinator.node_id, true)
	combinator.node_id = nil
	if not node then return nil end
	if not node.combinator_set[combinator.id] then
		strace(
			ERROR,
			"message",
			"referential inconsistency between associated combinator and node combinator set"
		)
		return nil
	end
	node.combinator_set[combinator.id] = nil
	cs2.raise_combinator_node_associated(combinator, nil, node)
	if not suppress_set_changed then
		cs2.raise_node_combinator_set_changed(node)
	end
	return node
end

-- When a combinator is destroyed, disassociate it from its node.
cs2.on_combinator_destroyed(function(combinator)
	if combinator.node_id then Node.disassociate_combinator(combinator) end
end)

---Get all combinators associated with this node.
---@param filter? fun(combinator: Cybersyn.Combinator): boolean? A filter function that returns `true` to include the combinator in the result.
---@return Cybersyn.Combinator[] #The combinators associated to the node, if any.
function Node:get_associated_combinators(filter)
	return tlib.t_map_a(self.combinator_set, function(_, combinator_id)
		local comb = Combinator.get(combinator_id, true)
		if comb and ((not filter) or filter(comb)) then return comb end
	end)
end

---Get the first combinator associated with this node and having the given
---mode.
---@param mode string
---@return Cybersyn.Combinator? #A combinator with the given mode associated to this node, if any.
function Node:get_combinator_with_mode(mode)
	for id in pairs(self.combinator_set) do
		local combinator = cs2.get_combinator(id, true)
		if combinator and combinator.mode == mode then return combinator end
	end
end

--------------------------------------------------------------------------------
-- Topology
--------------------------------------------------------------------------------

---Set the topology ID for this node.
---@param topology_id Id
function Node:set_topology(topology_id)
	if self.topology_id == topology_id then return end
	self.topology_id = topology_id
	cs2.raise_node_data_changed(self)
end

--------------------------------------------------------------------------------
-- Inventory
--------------------------------------------------------------------------------

---@param item SignalKey
---@return uint t_in Inbound threshold for the item
function Node:get_inbound_threshold(item)
	local ins = self.thresholds_in
	local is_fluid = key_is_fluid(item)
	if is_fluid then
		local tin = self.threshold_fluid_in or 1
		return ins and (ins[item] or tin) or tin
	else
		local mul = 1
		if self.stack_thresholds then mul = key_to_stacksize(item) or 1 end
		local base_tin = self.threshold_item_in
		local tin = base_tin and base_tin * mul or 1
		local item_in = ins and ins[item]
		return item_in and (item_in * mul) or tin
	end
end

---@param item SignalKey
---@return uint? t_in Inbound threshold for the item, or `nil` if not explicitly set
function Node:get_explicit_inbound_threshold(item)
	local ins = self.thresholds_in
	local is_fluid = key_is_fluid(item)
	if is_fluid then
		if ins and ins[item] then
			return ins[item]
		elseif self.threshold_fluid_in then
			return self.threshold_fluid_in
		end
	else
		local mul = 1
		if ins and ins[item] then
			if self.stack_thresholds then mul = key_to_stacksize(item) or 1 end
			return ins[item] * mul
		elseif self.threshold_item_in then
			if self.stack_thresholds then mul = key_to_stacksize(item) or 1 end
			return self.threshold_item_in * mul
		end
	end
end

---@param item SignalKey
---@return uint t_out Outbound threshold for the item
function Node:get_outbound_threshold(item)
	local outs = self.thresholds_out
	local is_fluid = key_is_fluid(item)
	if is_fluid then
		local tout = self.threshold_fluid_out or 1
		return outs and (outs[item] or tout) or tout
	else
		local mul = 1
		if self.stack_thresholds then mul = key_to_stacksize(item) or 1 end
		local base_tout = self.threshold_item_out
		local tout = base_tout and base_tout * mul or 1
		local item_out = outs and outs[item]
		return item_out and (item_out * mul) or tout
	end
end

---Get the inbound and outbound thresholds for the given item.
---@param item SignalKey
---@return uint t_in Inbound threshold for the item
---@return uint t_out Outbound threshold for the item
function Node:get_delivery_thresholds(item)
	local ins = self.thresholds_in
	local outs = self.thresholds_out
	local is_fluid = key_is_fluid(item)
	if is_fluid then
		local tin = self.threshold_fluid_in or 1
		local tout = self.threshold_fluid_out or 1
		return ins and (ins[item] or tin) or tin,
			outs and (outs[item] or tout) or tout
	else
		local mul = 1
		if self.stack_thresholds then mul = key_to_stacksize(item) or 1 end
		local base_tin = self.threshold_item_in
		local base_tout = self.threshold_item_out
		local tin = base_tin and base_tin * mul or 1
		local tout = base_tout and base_tout * mul or 1
		local item_in = ins and ins[item]
		local item_out = outs and outs[item]
		return item_in and (item_in * mul) or tin,
			item_out and (item_out * mul) or tout
	end
end

---@return Cybersyn.Inventory?
function Node:get_inventory() return cs2.get_inventory(self.inventory_id) end

---@return Cybersyn.Order[] orders All orders for this node. Treat as immutable.
function Node:get_orders()
	local inv = self:get_inventory()
	if not inv then return empty end
	return inv.orders
end

---Change the inventory of a node. If there are currently deliveries enroute
---they will be failed.
---@param id Id
---@return boolean was_changed `true` if the inventory was changed, `false` if not.
function Node:set_inventory(id)
	if id == self.inventory_id then return false end
	if not id then
		self.inventory_id = nil
		return true
	end
	local inv = Inventory.get(id)
	if not inv then
		self.inventory_id = nil
	else
		self.inventory_id = id
	end
	self:rebuild_inventory()
	return true
end

---Rebuild inventory for a node. Generally called when a structural change
---happens such as an inventory combinator being added or removed, or a sharing
---state change.
function Node:rebuild_inventory() end

--------------------------------------------------------------------------------
-- Deliveries
--------------------------------------------------------------------------------

---Get all deliveries involving this node.
---@return IdSet deliveries All pending deliveries for this node. Treat as immutable.
function Node:get_deliveries() return self.deliveries end

function Node:get_num_deliveries() return table_size(self.deliveries) end

---@param delivery_id Id?
---@return boolean success `true` if the delivery was added, `false` if it already exists.
function Node:add_delivery(delivery_id)
	if not delivery_id then return false end
	if self.deliveries[delivery_id] then
		strace(
			stlib.WARN,
			"message",
			"Node:add_delivery() called with existing delivery",
			delivery_id
		)
		return false
	end
	self.deliveries[delivery_id] = true
	self:defer_notify_deliveries()
	return true
end

---Remove a delivery from this node.
---@param delivery_id Id?
---@return boolean success `true` if the delivery was removed, `false` if it did not exist.
function Node:remove_delivery(delivery_id)
	if not delivery_id then return false end
	if not self.deliveries[delivery_id] then return false end
	self.deliveries[delivery_id] = nil
	self:defer_notify_deliveries()
	return true
end

---Fail ALL deliveries pending for this node.
function Node:fail_all_deliveries(reason)
	for delivery_id in pairs(self.deliveries) do
		local delivery = cs2.get_delivery(delivery_id, true)
		if delivery then delivery:fail(reason) end
	end
	self:defer_notify_deliveries()
end

---Cause a delivery update event to fire on a subsequent tick.
function Node:defer_notify_deliveries()
	if self.deferred_notify_deliveries then return end
	-- NOTE: 2 ticks used here because `defer_pop_queue` for train stops uses
	-- 1 tick, and we need to ensure that the deliveries are notified after.
	self.deferred_notify_deliveries =
		scheduler.at(game.tick + 2, "notify_deliveries", self)
end

scheduler.register_handler("notify_deliveries", function(task)
	local node = task.data --[[@as Cybersyn.Node]]
	node.deferred_notify_deliveries = nil
	cs2.raise_node_deliveries_changed(node)
end)
