--------------------------------------------------------------------------------
-- Base API for Cybersyn `Node` objects.
--------------------------------------------------------------------------------

local counters = require("__cybersyn2__.lib.counters")
local class = require("__cybersyn2__.lib.class").class
local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local signal = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local Inventory = _G.cs2.Inventory

local strace = stlib.strace
local ERROR = stlib.ERROR
local band = bit32.band
local pairs = _G.pairs
local key_is_fluid = signal.key_is_fluid
local key_to_stacksize = signal.key_to_stacksize
local Combinator = _G.cs2.Combinator

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
function Node.get(id, skip_validation)
	if not id then return nil end
	local node = storage.nodes[id]
	if skip_validation then
		return node
	else
		return node:is_valid() and node or nil
	end
end

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
---@param self Cybersyn.Node Reference to a *valid* node.
---@param filter? fun(combinator: Cybersyn.Combinator): boolean? A filter function that returns `true` to include the combinator in the result.
---@return Cybersyn.Combinator[] #The combinators associated to the node, if any.
function Node:get_associated_combinators(filter)
	return tlib.t_map_a(self.combinator_set, function(_, combinator_id)
		local comb = Combinator.get(combinator_id, true)
		if comb and ((not filter) or filter(comb)) then return comb end
	end)
end

---Get the per-item priority of the given item for this node, defaulting
---to the node's general priority or 0.
---@param item SignalKey
---@return int
function Node:get_item_priority(item)
	local prios = self.priorities
	local prio = self.priority or 0
	return prios and (prios[item] or prio) or prio
end

---Get this node's channel mask for an item
---@param item SignalKey
function Node:get_channel_mask(item)
	local channels = self.channels
	local channel = self.channel or 1 -- TODO: setting for global default chan
	return channels and (channels[item] or channel) or channel
end

---Determine if this node shares a network with the other.
---@param n2 Cybersyn.Node
function Node:is_network_match(n2, mode)
	local nets_1 = self.networks or {}
	local nets_2 = n2.networks or {}
	for k, v in pairs(nets_1) do
		-- TODO: setting for default global netmask
		if band(v, nets_2[k] or 1) ~= 0 then return true end
	end
	return false
end

---Determine if this node shares an item's channel with the other.
---@param self Cybersyn.Node
---@param n2 Cybersyn.Node
---@param item SignalKey
function Node:is_channel_match(n2, item)
	return band(self:get_channel_mask(item), n2:get_channel_mask(item)) ~= 0
end

---Determine if two nodes can exchange a given item.
---@param n2 Cybersyn.Node
---@param item SignalKey
function Node:is_item_match(n2, item)
	return self:is_channel_match(n2, item) and self:is_network_match(n2)
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
		local tin = (self.threshold_item_in * mul) or 1
		local tout = (self.threshold_item_out * mul) or 1
		return ins and ((ins[item] * mul) or tin) or tin,
			outs and ((outs[item] * mul) or tout) or tout
	end
end

---Determine how many of the given item the node can provide, accounting
---for thresholds and net inventory.
---@param item SignalKey
---@return integer #Providable quantity
---@return integer #Outbound DT, valid only if qty>0.
---@return Cybersyn.Inventory? #Node inventory
function Node:get_provide(item)
	local inv = Inventory.get(self.inventory_id)
	if not inv then return 0, 0, inv end
	local produce = inv:get_net_outflow()
	local has = produce[item] or 0
	if has <= 0 then return 0, 0, inv end
	local _, out_t = self:get_delivery_thresholds(item)
	if has < out_t then return 0, out_t, inv end
	return has, out_t, inv
end

---Determine how many of the given item the node can pull, accounting
---for thresholds and net inventory. Sign is flipped to positive.
---@return integer #Pullable quantity
---@return integer #Inbound DT, valid only if qty>0.
---@return Cybersyn.Inventory? #Node inventory
function Node:get_pull(item)
	local inv = Inventory.get(self.inventory_id)
	if not inv then return 0, 0, nil end
	local consume = inv:get_net_inflow()
	local has = consume[item] or 0
	if has >= 0 then return 0, 0, inv end
	has = -has
	local in_t = self:get_delivery_thresholds(item)
	if has < in_t then return 0, in_t, inv end
	return has, in_t, inv
end

---@return Cybersyn.Inventory?
function Node:get_inventory() return Inventory.get(self.inventory_id) end
