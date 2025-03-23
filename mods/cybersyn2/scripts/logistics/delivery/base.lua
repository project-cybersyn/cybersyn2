--------------------------------------------------------------------------------
-- Delivery abstraction
--------------------------------------------------------------------------------

local counters = require("__cybersyn2__.lib.counters")
local DeliveryState = require("__cybersyn2__.lib.types").DeliveryState
local log = require("__cybersyn2__.lib.logging")
local cs2 = _G.cs2
local delivery_api = _G.cs2.delivery_api

---Create a new delivery with the given initial parameters.
---@param vehicle_id Id
---@param manifest SignalCounts
---@param source_id Id
---@param destination_id Id
---@param source_inventory_id Id
---@param destination_inventory_id Id
---@return Cybersyn.Delivery
function _G.cs2.delivery_api.create_delivery(
	vehicle_id,
	manifest,
	source_id,
	destination_id,
	source_inventory_id,
	destination_inventory_id
)
	local id = counters.next("delivery")
	storage.deliveries[id] = {
		id = id,
		created_tick = game.tick,
		state_tick = game.tick,
		state = DeliveryState.Initializing,
		vehicle_id = vehicle_id,
		source_id = source_id,
		destination_id = destination_id,
		source_inventory_id = source_inventory_id,
		destination_inventory_id = destination_inventory_id,
		manifest = manifest,
	}
	cs2.raise_delivery_created(storage.deliveries[id])
	return storage.deliveries[id]
end

---Destroy a delivery.
---@param id Id
function _G.cs2.delivery_api.destroy_delivery(id)
	local delivery = storage.deliveries[id]
	if not delivery then
		return
	end
	cs2.raise_delivery_destroyed(delivery)
	storage.deliveries[id] = nil
end

---Change the state of a delivery.
---@param delivery Cybersyn.Delivery
---@param new_state Cybersyn.Delivery.State
function _G.cs2.delivery_api.set_state(delivery, new_state)
	if delivery.is_changing_state then
		if not delivery.queued_state_changes then
			delivery.queued_state_changes = { new_state }
		else
			table.insert(delivery.queued_state_changes, new_state)
		end
		return
	end

	local old_state = delivery.state
	if old_state == new_state then
		return
	end
	-- Returning a delivery to the Initializing state is forbidden
	if new_state == DeliveryState.Initializing then
		log.warn(
			"Attempt to return delivery to Initializing state, id",
			delivery.id
		)
		return
	end
	-- Taking a delivery out of completed state is forbidden
	if
		old_state == DeliveryState.Completed or old_state == DeliveryState.Failed
	then
		log.warn("Attempt to take delivery out of Completed state, id", delivery.id)
		return
	end
	delivery.state = new_state
	delivery.state_tick = game.tick

	delivery.is_changing_state = true
	cs2.raise_delivery_state_changed(delivery, new_state, old_state)
	delivery.is_changing_state = nil

	local queue = delivery.queued_state_changes
	if queue then
		delivery.queued_state_changes = nil
		for _, queued_state in pairs(queue) do
			delivery_api.set_state(delivery, queued_state)
		end
	end
end
