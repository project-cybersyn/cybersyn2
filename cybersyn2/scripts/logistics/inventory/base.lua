--------------------------------------------------------------------------------
-- Inventory abstraction
--------------------------------------------------------------------------------

local counters = require("__cybersyn2__.lib.counters")
local signal_keys = require("__cybersyn2__.lib.signal")
local DeliveryState = require("__cybersyn2__.lib.types").DeliveryState
local log = require("__cybersyn2__.lib.logging")

-- This code is called in high performance dispatch loops. We will take some
-- care to microoptimize here by using upvalues rather than globals. We will
-- also unroll loops, avoid table lookups, etc.

local next = _G.next
local pairs = _G.pairs
local signal_to_key = signal_keys.signal_to_key
local min = math.min
local max = math.max

local ToSource = DeliveryState.ToSource
local Loading = DeliveryState.Loading
local ToDestination = DeliveryState.ToDestination
local Unloading = DeliveryState.Unloading
local Completed = DeliveryState.Completed
local Failed = DeliveryState.Failed

inventory_api = {}

-- Inventory notes:
-- - Don't poll a station while a train is there, because result will be
-- inaccurate.
-- - Poll stations when trains leave.
-- - Allow logistics algorithm to access live polling data.

---Create a new inventory with the given initial parameters.
---@param owning_entity LuaEntity? If given, a *valid* entity that owns the inventory.
---@param surface_index int?
---@param node_ids IdSet? If given, the ID of the node that owns the inventory.
function inventory_api.create_inventory(owning_entity, surface_index, node_ids)
	local id
	if owning_entity then
		id = owning_entity.unit_number
	else
		id = -counters.next("inventory")
	end

	storage.inventories[ id --[[@as Id]] ] = {
		id = id --[[@as Id]],
		entity = owning_entity,
		surface_index = surface_index,
		node_ids = node_ids,
		provide = {},
		request = {},
	}

	raise_inventory_created(storage.inventories[id])
end

---Get an inventory by ID.
---@param inventory_id Id?
---@return Cybersyn.Inventory?
function inventory_api.get_inventory(inventory_id)
	if not inventory_id then return nil end
	return storage.inventories[inventory_id]
end
local get_inventory = inventory_api.get_inventory

---@param id Id
function inventory_api.destroy_inventory(id)
	local inventory = storage.inventories[id]
	if not inventory then return end
	raise_inventory_destroyed(inventory)
	storage.inventories[id] = nil
end

---@param inventory Cybersyn.Inventory
local function recompute_net(inventory)
	-- If no flow, net = base.
	if (not inventory.flow) or (not next(inventory.flow)) then
		inventory.flow = nil
		inventory.net_provide = nil
		inventory.net_request = nil
		return
	end
	local flow = inventory.flow --[[@as SignalCounts]]

	-- Compute net provide
	local provide = inventory.provide
	local net_provide = nil
	if next(provide) then
		net_provide = {}
		for key, count in pairs(provide) do
			local net = count + min(flow[key] or 0, 0)
			if net > 0 then net_provide[key] = net end
		end
	end
	inventory.net_provide = net_provide

	-- Compute net request
	local request = inventory.request
	local net_request = nil
	if next(request) then
		net_request = {}
		for key, count in pairs(request) do
			local net = count + max(flow[key] or 0, 0)
			if net < 0 then net_request[key] = net end
		end
	end
	inventory.net_request = net_request
end

---Set the core provide/rquest dataof this inventory from signal values obtained
---by polling live Factorio data.
---@param inventory Cybersyn.Inventory
---@param signals Signal[]
---@param allow_requests boolean Process requests (negative inventory)
---@param allow_provides boolean Process provides (positive inventory)
---@param allow_intangibles boolean? If `true`, allow non-item non-fluid signals.
---@return SignalID? intangible_signal_id If `allow_intangibles` is `false` and an intangible signal is found, returns one such signal.
function inventory_api.set_inventory_from_signals(inventory, signals, allow_requests, allow_provides, allow_intangibles)
	local intangible_signal_id = nil
	local provide = {}
	local request = {}

	for i = 1, #signals do
		local wrapper = signals[i]
		local signal = wrapper.signal
		local signal_type = signal.type
		local count = wrapper.count

		-- Filter intangible signals.
		if not allow_intangibles then
			if signal_type ~= "item" and signal_type ~= "fluid" then
				intangible_signal_id = signal
				goto continue
			end
		end

		-- Bucket signal into provide or request.
		-- This is unrolled on looking up the key signal for performance reasons.
		local key
		if count > 0 and allow_provides then
			key = signal_to_key(signal)
			if not key then goto continue end
			provide[key] = count
		elseif count < 0 and allow_requests then
			key = signal_to_key(signal)
			if not key then goto continue end
			request[key] = count
		end

		::continue::
	end

	inventory.provide = provide
	inventory.request = request
	recompute_net(inventory)
	return intangible_signal_id
end

---Add the given counts to the current flow of this inventory.
---@param inventory Cybersyn.Inventory
---@param added_flow SignalCounts
---@param sign int 1 to add the flow, -1 to subtract it.
function inventory_api.add_flow(inventory, added_flow, sign)
	local flow = inventory.flow or {}
	local provide = inventory.provide
	local request = inventory.request
	local net_provide = inventory.net_provide
	local net_request = inventory.net_request

	for key, count in pairs(added_flow) do
		local new_flow = (flow[key] or 0) + sign * count
		if new_flow == 0 then
			flow[key] = nil
		else
			flow[key] = new_flow
		end
		-- Update net provide and request entries.
		-- This is highly unrolled for performance reasons.
		if new_flow < 0 then
			local p_count = provide[key]
			if p_count then
				local net = p_count + new_flow
				if net > 0 then
					if not net_provide then
						net_provide = {}
						inventory.net_provide = net_provide
					end
					net_provide[key] = net
				else
					if net_provide then net_provide[key] = nil end
				end
			end
		elseif new_flow > 0 then
			local r_count = request[key]
			if r_count then
				local net = r_count + new_flow
				if net < 0 then
					if not net_request then
						net_request = {}
						inventory.net_request = net_request
					end
					net_request[key] = net
				else
					if net_request then net_request[key] = nil end
				end
			end
		else -- new_flow == 0
			if net_provide then net_provide[key] = provide[key] end
			if net_request then net_request[key] = request[key] end
		end
	end

	if next(flow) then
		inventory.flow = flow
	else
		inventory.flow = nil
		inventory.net_provide = nil
		inventory.net_request = nil
	end
end

---Get the net provides of this inventory. This is a READ-ONLY cached table
---that should not be retained beyond the current tick.
---@param inventory Cybersyn.Inventory
---@return SignalCounts
function inventory_api.get_net_provides(inventory)
	return inventory.net_provide or inventory.provide
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

on_delivery_state_changed(function(delivery, new_state, old_state)
	local source_inv = get_inventory(delivery.source_inventory_id)
	local dest_inv = get_inventory(delivery.destination_inventory_id)
	if not source_inv then
		log.error("inventory.on_delivery_state_changed: Delivery", delivery.id, "has no source inventory")
		return
	end
	if not dest_inv then
		log.error("inventory.on_delivery_state_changed: Delivery", delivery.id, "has no destination inventory")
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
