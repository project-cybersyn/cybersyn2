--------------------------------------------------------------------------------
-- Inventory abstraction
--------------------------------------------------------------------------------

local counters = require("__cybersyn2__.lib.counters")
local signal_keys = require("__cybersyn2__.lib.signal")
local DeliveryState = require("__cybersyn2__.lib.types").DeliveryState
local log = require("__cybersyn2__.lib.logging")
local cs2 = _G.cs2
local inventory_api = _G.cs2.inventory_api

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

---Create a new inventory with the given initial parameters.
---@param owning_entity LuaEntity? If given, a *valid* entity that owns the inventory.
---@param surface_index int?
---@param node_ids IdSet? If given, the ID of the node that owns the inventory.
function _G.cs2.inventory_api.create_inventory(
	owning_entity,
	surface_index,
	node_ids
)
	local id
	if owning_entity then
		id = owning_entity.unit_number
	else
		id = -counters.next("inventory")
	end

	storage.inventories[
		id --[[@as Id]]
	] = {
		id = id --[[@as Id]],
		entity = owning_entity,
		surface_index = surface_index,
		node_ids = node_ids,
		produce = {},
		consume = {},
	}

	cs2.raise_inventory_created(storage.inventories[id])
end

---Get an inventory by ID.
---@param inventory_id Id?
---@return Cybersyn.Inventory?
function _G.cs2.inventory_api.get_inventory(inventory_id)
	if not inventory_id then return nil end
	return storage.inventories[inventory_id]
end
local get_inventory = inventory_api.get_inventory

---@param id Id
function _G.cs2.inventory_api.destroy_inventory(id)
	local inventory = storage.inventories[id]
	if not inventory then return end
	cs2.raise_inventory_destroyed(inventory)
	storage.inventories[id] = nil
end

---@param inventory Cybersyn.Inventory
local function recompute_net(inventory)
	-- If no flow, net = base.
	if (not inventory.flow) or (not next(inventory.flow)) then
		inventory.flow = nil
		inventory.net_produce = nil
		inventory.net_consume = nil
		return
	end
	local flow = inventory.flow --[[@as SignalCounts]]

	-- Compute net produce
	local produce = inventory.produce
	local net_produce = nil
	if next(produce) then
		net_produce = {}
		for key, count in pairs(produce) do
			local net = count + min(flow[key] or 0, 0)
			if net > 0 then net_produce[key] = net end
		end
	end
	inventory.net_produce = net_produce

	-- Compute net consume
	local consume = inventory.consume
	local net_consume = nil
	if next(consume) then
		net_consume = {}
		for key, count in pairs(consume) do
			local net = count + max(flow[key] or 0, 0)
			if net < 0 then net_consume[key] = net end
		end
	end
	inventory.net_consume = net_consume
end

---Set the core produce/consume data of this inventory from signal values obtained
---by polling live Factorio data.
---@param inventory Cybersyn.Inventory
---@param signals SignalCounts
---@param is_consumer boolean Process consumes (negative inventory)
---@param is_producer boolean Process produces (positive inventory)
function _G.cs2.inventory_api.set_base_inventory(
	inventory,
	signals,
	is_consumer,
	is_producer
)
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

	inventory.produce = produce
	inventory.consume = consume
	recompute_net(inventory)
end

---Add the given counts to the current flow of this inventory.
---@param inventory Cybersyn.Inventory
---@param added_flow SignalCounts
---@param sign int 1 to add the flow, -1 to subtract it.
function _G.cs2.inventory_api.add_flow(inventory, added_flow, sign)
	local flow = inventory.flow or {}
	local produce = inventory.produce
	local consume = inventory.consume
	local net_produce = inventory.net_produce
	local net_consume = inventory.net_consume

	for key, count in pairs(added_flow) do
		local new_flow = (flow[key] or 0) + sign * count
		if new_flow == 0 then
			flow[key] = nil
		else
			flow[key] = new_flow
		end
		-- Update net produce and consume entries.
		-- This is highly unrolled for performance reasons.
		if new_flow < 0 then
			local p_count = produce[key]
			if p_count then
				local net = p_count + new_flow
				if net > 0 then
					if not net_produce then
						net_produce = {}
						inventory.net_produce = net_produce
					end
					net_produce[key] = net
				else
					if net_produce then net_produce[key] = nil end
				end
			end
		elseif new_flow > 0 then
			local r_count = consume[key]
			if r_count then
				local net = r_count + new_flow
				if net < 0 then
					if not net_consume then
						net_consume = {}
						inventory.net_consume = net_consume
					end
					net_consume[key] = net
				else
					if net_consume then net_consume[key] = nil end
				end
			end
		else -- new_flow == 0
			if net_produce then net_produce[key] = produce[key] end
			if net_consume then net_consume[key] = consume[key] end
		end
	end

	if next(flow) then
		inventory.flow = flow
	else
		inventory.flow = nil
		inventory.net_produce = nil
		inventory.net_consume = nil
	end
end

---Get the net produces of this inventory. This is a READ-ONLY cached table
---that should not be retained beyond the current tick.
---@param inventory Cybersyn.Inventory
---@return SignalCounts
function _G.cs2.inventory_api.get_net_produce(inventory)
	return inventory.net_produce or inventory.produce
end

---Get the net consumes of this inventory. This is a READ-ONLY cached table
---that should not be retained beyond the current tick.
---@param inventory Cybersyn.Inventory
---@return SignalCounts
function _G.cs2.inventory_api.get_net_consume(inventory)
	return inventory.net_consume or inventory.consume
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- TODO: reexamine this in light of reservation systems.
cs2.on_delivery_state_changed(function(delivery, new_state, old_state)
	local source_inv = get_inventory(delivery.source_inventory_id)
	local dest_inv = get_inventory(delivery.destination_inventory_id)
	if not source_inv then
		log.error(
			"inventory.on_delivery_state_changed: Delivery",
			delivery.id,
			"has no source inventory"
		)
		return
	end
	if not dest_inv then
		log.error(
			"inventory.on_delivery_state_changed: Delivery",
			delivery.id,
			"has no destination inventory"
		)
		return
	end
	if new_state == ToSource then
		-- When the delivery begins its journey, charge the source and
		-- credit the destination with the manifest.
		inventory_api.add_flow(source_inv, delivery.manifest, -1)
		inventory_api.add_flow(dest_inv, delivery.manifest, 1)
	elseif new_state == ToDestination then
		-- When the delivery leaves the source, no longer need to charge the
		-- manifest against the source's inventory
		inventory_api.add_flow(source_inv, delivery.manifest, 1)
	elseif new_state == Completed then
		-- No longer need to add the manifest to the destination's inventory
		inventory_api.add_flow(dest_inv, delivery.manifest, -1)
	elseif new_state == Failed then
		if old_state == ToSource or old_state == Loading then
			-- Failed at source, add back both charges
			inventory_api.add_flow(source_inv, delivery.manifest, 1)
			inventory_api.add_flow(dest_inv, delivery.manifest, -1)
		elseif old_state == ToDestination or old_state == Unloading then
			-- Failed at destination, add back only the charge to the destination
			inventory_api.add_flow(dest_inv, delivery.manifest, -1)
		end
	end
end)
