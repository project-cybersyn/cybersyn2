--------------------------------------------------------------------------------
-- Base API for Cybersyn `Node` objects.
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local log = require("__cybersyn2__.lib.logging")
local signal = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local node_api = _G.cs2.node_api
local combinator_api = _G.cs2.combinator_api
local inventory_api = _G.cs2.inventory_api

local band = bit32.band
local pairs = _G.pairs
local key_is_fluid = signal.key_is_fluid

---@param node_id Id?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.Node?
function _G.cs2.node_api.get_node(node_id, skip_validation)
	if not node_id then return nil end
	return storage.nodes[node_id]
end

---Associate the given combinator with the given node.
---@param node Cybersyn.Node? Reference to a *valid* node.
---@param combinator Cybersyn.Combinator.Internal Reference to a *valid* combinator.
---@param suppress_set_changed boolean? If `true`, does not raise the `node_combinator_set_changed` event. You must do so yourself if performing a batch of updates.
---@return boolean success `true` if the combinator was successfully associated, `false` if not.
---@return Cybersyn.Node? old_node The node that the combinator was previously associated with, if any.
function _G.cs2.node_api.associate_combinator(
	node,
	combinator,
	suppress_set_changed
)
	if not node then return false end
	local old_node
	if combinator.node_id and combinator.node_id ~= node.id then
		-- Combinator is already associated with a different node.
		old_node = node_api.get_node(combinator.node_id, true)
		node_api.disassociate_combinator(combinator, suppress_set_changed)
	end

	if not node.combinator_set[combinator.id] then
		node.combinator_set[combinator.id] = true
		combinator.node_id = node.id
		cs2.raise_combinator_node_associated(combinator, node, nil)
		if not suppress_set_changed then
			cs2.raise_node_combinator_set_changed(node)
		end
		return true, old_node
	end

	return false, old_node
end

---Disassociate the given combinator from its associated node if any.
---@param combinator Cybersyn.Combinator.Internal? Reference to a *valid* combinator.
---@param suppress_set_changed boolean? If `true`, does not raise the `node_combinator_set_changed` event. You must do so yourself if performing a batch of updates.
---@return Cybersyn.Node? old_node If the combinator was disassociated, the node that it was disassociated from, otherwise `nil`.
function _G.cs2.node_api.disassociate_combinator(
	combinator,
	suppress_set_changed
)
	if not combinator then return nil end
	local node = node_api.get_node(combinator.node_id, true)
	combinator.node_id = nil
	if not node then return nil end
	if not node.combinator_set[combinator.id] then
		log.error(
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

---Get all combinators associated with this node.
---@param node Cybersyn.Node Reference to a *valid* node.
---@param filter? fun(combinator: Cybersyn.Combinator.Internal): boolean? A filter function that returns `true` to include the combinator in the result.
---@return Cybersyn.Combinator.Internal[] #The combinators associated to the node, if any.
function _G.cs2.node_api.get_associated_combinators(node, filter)
	return tlib.t_map_a(node.combinator_set, function(_, combinator_id)
		local comb = combinator_api.get_combinator(combinator_id, true)
		if comb and ((not filter) or filter(comb)) then return comb end
	end)
end

---Get the per-item priority of the given item for this node, defaulting
---to the node's general priority or 0.
---TODO: determine whether to hardcode default priority to 0 (yes)
---@param node Cybersyn.Node
---@param item SignalKey
local function get_item_priority(node, item)
	local prios = node.priorities
	local prio = node.priority or 0
	return prios and (prios[item] or prio) or prio
end
_G.cs2.node_api.get_item_priority = get_item_priority

---@param node Cybersyn.Node
---@param item SignalKey
local function get_channel_mask(node, item)
	local channels = node.channels
	local channel = node.channel or 1 -- TODO: setting for global default chan
	return channels and (channels[item] or channel) or channel
end
_G.cs2.node_api.get_channel_mask = get_channel_mask

---Determine if two nodes share a network.
---@param n1 Cybersyn.Node
---@param n2 Cybersyn.Node
local function is_network_match(n1, n2, mode)
	local nets_1 = n1.networks or {}
	local nets_2 = n2.networks or {}
	for k, v in pairs(nets_1) do
		-- TODO: setting for default global netmask
		if band(v, nets_2[k] or 1) ~= 0 then return true end
	end
	return false
end
_G.cs2.node_api.is_network_match = is_network_match

---Determine if two nodes share a channel for an item
---@param n1 Cybersyn.Node
---@param n2 Cybersyn.Node
---@param item SignalKey
local function is_channel_match(n1, n2, item)
	return band(get_channel_mask(n1, item), get_channel_mask(n2, item)) ~= 0
end
_G.cs2.node_api.is_channel_match = is_channel_match

---Determine if two nodes can exchange a given item.
---@param n1 Cybersyn.Node
---@param n2 Cybersyn.Node
---@param item SignalKey
local function is_item_match(n1, n2, item)
	return is_channel_match(n1, n2, item) and is_network_match(n1, n2)
end
_G.cs2.node_api.is_item_match = is_item_match

---Get the inbound and outbound thresholds for the given item.
---@param node Cybersyn.Node
---@param item SignalKey
local function get_delivery_thresholds(node, item)
	local ins = node.thresholds_in
	local outs = node.thresholds_out
	local is_fluid = key_is_fluid(item)
	if is_fluid then
		local tin = node.threshold_fluid_in or 1
		local tout = node.threshold_fluid_out or 1
		return ins and (ins[item] or tin) or tin,
			outs and (outs[item] or tout) or tout
	else
		local tin = node.threshold_item_in or 1
		local tout = node.threshold_item_out or 1
		return ins and (ins[item] or tin) or tin,
			outs and (outs[item] or tout) or tout
	end
end
_G.cs2.node_api.get_delivery_thresholds = get_delivery_thresholds

---Determine how many of the given item the node can provide, accounting
---for thresholds and net inventory.
---@param node Cybersyn.Node
---@param item SignalKey
---@return integer #Providable quantity
---@return integer #Outbound DT, valid only if qty>0.
---@return Cybersyn.Inventory #Node inventory
function _G.cs2.node_api.get_provide(node, item)
	local inv, produce = inventory_api.get_inventory_info_by_id(node.inventory_id)
	if not inv then return 0, 0, inv end
	local has = produce[item] or 0
	if has == 0 then return 0, 0, inv end
	local _, out_t = get_delivery_thresholds(node, item)
	if has < out_t then return 0, out_t, inv end
	return has, out_t, inv
end

---Determine how many of the given item the node can pull, accounting
---for thresholds and net inventory.
---@return integer #Pullable quantity
---@return integer #Inbound DT, valid only if qty>0.
---@return Cybersyn.Inventory #Node inventory
function _G.cs2.node_api.get_pull(node, item)
	local inv, _, consume =
		inventory_api.get_inventory_info_by_id(node.inventory_id)
	if not inv then return 0, 0, nil end
	local has = consume[item] or 0
	if has == 0 then return 0, 0, inv end
	has = -has
	local in_t = get_delivery_thresholds(node, item)
	if has < in_t then return 0, in_t, inv end
	return has, in_t, inv
end
