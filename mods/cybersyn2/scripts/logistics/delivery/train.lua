--------------------------------------------------------------------------------
-- Train delivery controller
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local siglib = require("__cybersyn2__.lib.signal")
local stlib = require("__cybersyn2__.lib.strace")

local strace = stlib.strace
local key_is_fluid = siglib.key_is_fluid
local key_to_signal = siglib.key_to_signal
local Delivery = _G.cs2.Delivery
local Inventory = _G.cs2.Inventory
local TrainStop = _G.cs2.TrainStop
local Train = _G.cs2.Train

---@class Cybersyn.TrainDelivery
local TrainDelivery = class("TrainDelivery", Delivery)
_G.cs2.TrainDelivery = TrainDelivery

---@param train Cybersyn.Train A *valid and available* Cybersyn train.
---@param from Cybersyn.TrainStop
---@param from_inv Cybersyn.Inventory
---@param to Cybersyn.TrainStop
---@param to_inv Cybersyn.Inventory
---@param manifest SignalCounts
---@param from_charge SignalCounts
function TrainDelivery.new(
	train,
	from,
	from_inv,
	to,
	to_inv,
	manifest,
	from_charge
)
	local delivery = Delivery.new("train")
	setmetatable(delivery, TrainDelivery)
	---@cast delivery Cybersyn.TrainDelivery
	delivery.manifest = manifest
	delivery.from_id = from.id
	delivery.to_id = to.id
	delivery.from_inventory_id = from_inv.id
	delivery.to_inventory_id = to_inv.id
	cs2.raise_delivery_created(delivery)
	-- Check if some bizarre side effect invalidated us
	if not delivery:is_valid() then return nil end

	delivery.to_charge = manifest
	delivery.from_charge = from_charge
	from_inv:add_flow(from_charge, -1)
	to_inv:add_flow(manifest, 1)
	delivery.vehicle_id = train.id
	train:set_delivery(delivery)

	-- Immediately start the delivery
	delivery:goto_from()

	return delivery
end

---Clear virtual charge on `from` inventory.
function TrainDelivery:clear_from_charge()
	if self.from_charge then
		local from_inv = Inventory.get(self.from_inventory_id)
		if from_inv then from_inv:add_flow(self.from_charge, 1) end
		self.from_charge = nil
	end
end

---Clear virtual charge on `to` inventory.
function TrainDelivery:clear_to_charge()
	if self.to_charge then
		local to_inv = Inventory.get(self.to_inventory_id)
		if to_inv then to_inv:add_flow(self.to_charge, -1) end
		self.to_charge = nil
	end
end

---Clear all consequences of this delivery from queues, caches etc
function TrainDelivery:force_clear()
	self:clear_to_charge()
	self:clear_from_charge()
	local from_stop = TrainStop.get(self.from_id)
	if from_stop then from_stop:force_remove_delivery(self.id) end
	local to_stop = TrainStop.get(self.to_id)
	if to_stop then to_stop:force_remove_delivery(self.id) end
	local train = Train.get(self.vehicle_id)
	if train then train:clear_delivery() end
end

function TrainDelivery:enter_failed() self:force_clear() end

---@param stop_entity LuaEntity
local function coordinate_entry(stop_entity)
	---@type AddRecordData
	local add = {
		rail = stop_entity.connected_rail,
		rail_direction = stop_entity.connected_rail_direction,
	}
	return add
end

---@param stop Cybersyn.TrainStop
---@param manifest SignalCounts
local function pickup_entry(stop, manifest)
	---@type WaitCondition[]
	local conditions = {}
	-- TODO: honor enable/disable cargo condition
	for key, qty in pairs(manifest) do
		local cond_type = key_is_fluid(key) and "fluid_count" or "item_count"
		conditions[#conditions + 1] = {
			type = cond_type,
			compare_type = "and",
			condition = {
				comparator = ">=",
				first_signal = key_to_signal(key),
				constant = qty,
			},
		}
	end
	-- TODO: inactivity
	-- TODO: circuit
	-- TODO: circuit forceout
	-- TODO: timer forceout
	---@type AddRecordData
	local add = {
		station = stop.entity.backer_name,
		wait_conditions = conditions,
	}
	return add
end

local function dropoff_entry(stop)
	---@type WaitCondition[]
	local conditions = {}
	-- TODO: honor enable/disable cargo condition
	conditions[#conditions + 1] = {
		type = "empty",
		compare_type = "and",
	}
	-- TODO: inactivity
	-- TODO: circuit
	-- TODO: circuit forceout
	-- TODO: timer forceout
	---@type AddRecordData
	local add = {
		station = stop.entity.backer_name,
		wait_conditions = conditions,
	}
	return add
end

function TrainDelivery:goto_from()
	local train = Train.get(self.vehicle_id)
	local from = TrainStop.get(self.from_id)
	if not train or not from then return self:fail() end
	if from:is_full() then
		-- Queue up in the stop's delivery queue
		from:enqueue(self.id)
		self:set_state("wait_from")
	else
		if
			train:schedule(
				coordinate_entry(from.entity),
				pickup_entry(from, self.manifest)
			)
		then
			from:add_delivery(self.id)
			self:set_state("to_from")
		else
			self:set_state("interrupted_from")
		end
	end
end

function TrainDelivery:goto_to()
	local train = Train.get(self.vehicle_id)
	local to = TrainStop.get(self.to_id)
	if not train or not to then return self:fail() end
	self:clear_from_charge()
	if to:is_full() then
		-- Queue up in the stop's delivery queue
		to:enqueue(self.id)
		self:set_state("wait_to")
	else
		if train:schedule(coordinate_entry(to.entity), dropoff_entry(to)) then
			to:add_delivery(self.id)
			self:set_state("to_to")
		else
			self:set_state("interrupted_to")
		end
	end
end

function TrainDelivery:complete()
	self:clear_from_charge()
	self:clear_to_charge()
	self:set_state("completed")
	local train = Train.get(self.vehicle_id)
	if train then train:clear_delivery() end
end

---Train stop invokes this to notify a train on this delivery left
---that stop
function TrainDelivery:notify_departed(stop)
	if self.state == "to_from" and stop.id == self.from_id then
		self:goto_to()
	elseif self.state == "to_to" and stop.id == self.to_id then
		self:complete()
	else
		strace(
			stlib.WARN,
			"cs2",
			"delivery_departed",
			"delivery",
			self,
			"message",
			"notify_departed() was called out of context."
		)
	end
end

---Train stop invokes this to notify us that a queue we were waiting
---in has become ready.
---@param stop Cybersyn.TrainStop
function TrainDelivery:notify_queue(stop)
	if self.state == "wait_from" and stop.id == self.from_id then
		self:goto_from()
	elseif self.state == "wait_to" and stop.id == self.to_id then
		self:goto_to()
	else
		strace(
			stlib.WARN,
			"cs2",
			"delivery_queue",
			"delivery",
			self,
			"message",
			"notify_queue() was called while we weren't supposed to be queued."
		)
	end
end

function TrainDelivery:notify_interrupted()
	if self.state == "interrupted_from" then
		self:goto_from()
	elseif self.state == "interrupted_to" then
		self:goto_to()
	end
end

---If a train arrives at or departs a non-Cybersyn station while it's
---interrupted, attempt to retry the delivery.
---@param cstrain Cybersyn.Train?
local function interrupt_checker(train, cstrain, stop)
	-- TODO: if cybersyn stops ever support interrupts, change this logic
	if cstrain and not stop and cstrain.delivery_id then
		local delivery = Delivery.get(cstrain.delivery_id) --[[@as Cybersyn.TrainDelivery?]]
		if delivery then delivery:notify_interrupted() end
	end
end

cs2.on_train_arrived(interrupt_checker)

cs2.on_train_departed(interrupt_checker)

-- init: Virtual charges against source and dest inventory
-- wait_from: Check for open slot at source and enter queue
-- to_from: Add schedule for source
-- interrupted_from: Train was interrupted while trying to get to `from`, reschedule to `from` when it hits depot.
-- wait_to: Clear virtual charge from source inventory, check for open slot at dest and enter queue
-- to_to: Add schedule for dest.
-- completed: Clear virtual charge from dest
-- failed: Clear any virtual charges, remove from any queue slots
