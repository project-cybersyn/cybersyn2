--------------------------------------------------------------------------------
-- Train delivery controller
--------------------------------------------------------------------------------

-- States:
-- init: Virtual charges against source and dest inventory
-- wait_from: Check for open slot at source and enter queue
-- to_from: Add schedule for source
-- interrupted_from: Train was interrupted while trying to get to `from`, reschedule to `from` when it hits depot.
-- wait_to: Clear virtual charge from source inventory, check for open slot at dest and enter queue
-- to_to: Add schedule for dest.
-- completed: Clear virtual charge from dest
-- failed: Clear any virtual charges, remove from any queue slots

local class = require("__cybersyn2__.lib.class").class
local siglib = require("__cybersyn2__.lib.signal")
local stlib = require("__cybersyn2__.lib.strace")
local tlib = require("__cybersyn2__.lib.table")
local thread_lib = require("__cybersyn2__.lib.thread")

local empty = tlib.empty
local strace = stlib.strace
local key_is_fluid = siglib.key_is_fluid
local key_to_signal = siglib.key_to_signal
local Delivery = _G.cs2.Delivery
local Inventory = _G.cs2.Inventory
local TrainStop = _G.cs2.TrainStop
local Train = _G.cs2.Train
local Thread = thread_lib.Thread

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
---@param spillover uint
---@param reserved_slots uint
---@param reserved_capacity uint
function TrainDelivery.new(
	train,
	from,
	from_inv,
	to,
	to_inv,
	manifest,
	from_charge,
	spillover,
	reserved_slots,
	reserved_capacity
)
	local delivery = Delivery.new("train")
	setmetatable(delivery, TrainDelivery)
	---@cast delivery Cybersyn.TrainDelivery
	delivery.manifest = manifest
	delivery.from_id = from.id
	delivery.to_id = to.id
	delivery.from_inventory_id = from_inv.id
	delivery.to_inventory_id = to_inv.id
	delivery.spillover = spillover
	delivery.reserved_slots = reserved_slots
	delivery.reserved_fluid_capacity = reserved_capacity

	delivery.to_charge = manifest
	delivery.from_charge = from_charge
	from_inv:add_outflow(from_charge, 1)
	to_inv:add_inflow(manifest, 1)
	delivery.vehicle_id = train.id
	train:set_delivery(delivery)

	from:add_delivery(delivery.id)
	to:add_delivery(delivery.id)
	delivery:set_state("wait_from")
	from:enqueue(delivery.id)

	cs2.raise_delivery_created(delivery)
	return delivery
end

---Clear virtual charge on `from` inventory.
function TrainDelivery:clear_from_charge()
	if self.from_charge then
		local from_inv = Inventory.get(self.from_inventory_id)
		if from_inv then from_inv:add_outflow_rebate(self.from_charge, -1) end
		self.from_charge = nil
	end
end

---Clear virtual charge on `to` inventory.
function TrainDelivery:clear_to_charge()
	if self.to_charge then
		local to_inv = Inventory.get(self.to_inventory_id)
		if to_inv then to_inv:add_inflow_rebate(self.to_charge, -1) end
		self.to_charge = nil
	end
end

---Clear all consequences of this delivery from queues, caches etc
function TrainDelivery:force_clear()
	self:clear_to_charge()
	self:clear_from_charge()
	local from_stop = TrainStop.get(self.from_id)
	if from_stop then from_stop:remove_delivery(self.id) end
	local to_stop = TrainStop.get(self.to_id)
	if to_stop then to_stop:remove_delivery(self.id) end
	local train = Train.get(self.vehicle_id)
	if train then train:fail_delivery(self.id) end
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

---@param conditions WaitCondition[]
---@param stop Cybersyn.TrainStop
local function add_controlled_out_conditions(conditions, stop)
	if
		(stop.inactivity_timeout or 0) > 0 and stop.inactivity_mode == "deliver"
	then
		conditions[#conditions + 1] = {
			type = "inactivity",
			compare_type = "and",
			ticks = stop.inactivity_timeout,
		}
	end
	if stop.allow_departure_signal then
		conditions[#conditions + 1] = {
			type = "circuit",
			compare_type = "and",
			condition = {
				comparator = ">",
				constant = 0,
				first_signal = stop.allow_departure_signal,
			},
		}
	end
end

---@param conditions WaitCondition[]
---@param stop Cybersyn.TrainStop
local function add_forceout_conditions(conditions, stop)
	if stop.force_departure_signal then
		conditions[#conditions + 1] = {
			type = "circuit",
			compare_type = "or",
			condition = {
				comparator = ">",
				constant = 0,
				first_signal = stop.force_departure_signal,
			},
		}
		conditions[#conditions + 1] = {
			type = "inactivity",
			compare_type = "and",
			ticks = 60,
		}
	end
	if
		(stop.inactivity_timeout or 0) > 0 and stop.inactivity_mode == "forceout"
	then
		conditions[#conditions + 1] = {
			type = "inactivity",
			compare_type = "or",
			ticks = stop.inactivity_timeout,
		}
	end
end

---@param conditions WaitCondition[]
---@param stop Cybersyn.TrainStop
local function forbid_empty_conditions(conditions, stop)
	if #conditions == 0 then
		conditions[#conditions + 1] = {
			type = "inactivity",
			ticks = 60,
		}
	end
end

---@param stop Cybersyn.TrainStop
---@param manifest SignalCounts
local function pickup_entry(stop, manifest)
	---@type WaitCondition[]
	local conditions = {}
	if not stop.disable_cargo_condition then
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
	end
	add_controlled_out_conditions(conditions, stop)
	add_forceout_conditions(conditions, stop)
	forbid_empty_conditions(conditions, stop)
	---@type AddRecordData
	local add = {
		station = stop.entity.backer_name,
		wait_conditions = conditions,
	}
	return add
end

---@param stop Cybersyn.TrainStop
local function dropoff_entry(stop)
	---@type WaitCondition[]
	local conditions = {}
	if not stop.disable_cargo_condition then
		conditions[#conditions + 1] = {
			type = "empty",
			compare_type = "and",
		}
	end
	add_controlled_out_conditions(conditions, stop)
	add_forceout_conditions(conditions, stop)
	forbid_empty_conditions(conditions, stop)
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
	if self.state == "to_from" then return end
	local ok, reason = train:schedule(
		coordinate_entry(from.entity),
		pickup_entry(from, self.manifest)
	)
	if ok then
		self:set_state("to_from")
	elseif reason == "interrupted" then
		self:set_state("interrupted_from")
	else
		-- TODO: failed to add schedule record, what now?
	end
end

function TrainDelivery:goto_to()
	local train = Train.get(self.vehicle_id)
	local to = TrainStop.get(self.to_id)
	if not train or not to then return self:fail() end
	self:clear_from_charge()
	if self.state == "to_to" then return end
	local ok, reason =
		train:schedule(coordinate_entry(to.entity), dropoff_entry(to))
	if ok then
		self:set_state("to_to")
	elseif reason == "interrupted" then
		self:set_state("interrupted_to")
	else
		-- TODO: failed to add schedule record, what now?
	end
end

function TrainDelivery:complete()
	self:clear_from_charge()
	self:clear_to_charge()
	self:set_state("completed")
	local train = Train.get(self.vehicle_id)
	if train then
		train:clear_delivery(self.id)
		if not train:is_empty() then
			self.left_dirty = "Train was not fully unloaded at destination."
			-- TODO: tainted train handling
		end
	end
end

---Train stop invokes this to notify a train on this delivery left
---that stop
function TrainDelivery:notify_departed(stop)
	if self.state == "to_from" and stop.id == self.from_id then
		self:clear_from_charge()
		local to = TrainStop.get(self.to_id)
		if not to then return self:fail() end
		self:set_state("wait_to")
		to:enqueue(self.id)
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

---Train stop invokes this to notify a train on this delivery_id
---arrived at the stop.
---@param stop Cybersyn.TrainStop
function TrainDelivery:notify_arrived(stop)
	if self.state == "to_from" then
		if stop.id ~= self.from_id then
			local priority = stop.entity.train_stop_priority
			-- TODO: misrouted warning/handling
			self.misrouted_from = string.format(
				"wrong source: expected %d, got %d. prio %d",
				self.from_id,
				stop.id,
				priority
			)
		end
	elseif self.state == "to_to" then
		if stop.id ~= self.to_id then
			local priority = stop.entity.train_stop_priority
			-- TODO: misrouted warning/handling
			self.misrouted_to = string.format(
				"wrong sink: expected %d, got %d. prio %d",
				self.to_id,
				stop.id,
				priority
			)
		end
	end
end

---Train stop invokes this to notify us that a queue we were waiting
---in has become ready.
---@param stop Cybersyn.TrainStop
function TrainDelivery:notify_queue(stop)
	if self.state == "wait_from" and stop.id == self.from_id then
		cs2.enqueue_delivery_operation(self, "goto_from")
	elseif self.state == "wait_to" and stop.id == self.to_id then
		cs2.enqueue_delivery_operation(self, "goto_to")
	end
end

function TrainDelivery:notify_interrupted()
	if self.state == "interrupted_from" then
		cs2.enqueue_delivery_operation(self, "goto_from")
	elseif self.state == "interrupted_to" then
		cs2.enqueue_delivery_operation(self, "goto_to")
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

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

cs2.on_train_arrived(interrupt_checker)

cs2.on_train_departed(interrupt_checker)

---@param luatrain LuaTrain
---@param old_name string
---@param new_name string
local function rename_stop_in_schedule(luatrain, old_name, new_name)
	if not luatrain or not luatrain.valid then return end
	local schedule = luatrain.get_schedule()
	if not schedule then return end
	local records = schedule.get_records()
	if not records then return end
	for i, record in ipairs(records) do
		if record.temporary and record.station == old_name then
			local new_record = record --[[@as AddRecordData]]
			new_record.station = new_name
			new_record.index = { schedule_index = i }
			-- replace the record in the schedule
			local is_current = schedule.current == i
			schedule.remove_record(new_record.index)
			schedule.add_record(new_record)
			if is_current and schedule.current ~= i then schedule.go_to_station(i) end
		end
	end
end

-- When a train stop is renamed, rename the stop in any schedules of LuaTrains
-- that may be using the stop.
cs2.on_entity_renamed(function(renamed_type, entity, old_name)
	if renamed_type ~= "train-stop" then return end
	local stop = TrainStop.get_stop_from_unit_number(entity.unit_number)
	if not stop then return end
	for _, delivery_id in pairs(stop.delivery_queue or empty) do
		local delivery = Delivery.get(delivery_id) --[[@as Cybersyn.TrainDelivery?]]
		if delivery then
			local train = Train.get(delivery.vehicle_id)
			if train then
				rename_stop_in_schedule(train.lua_train, old_name, entity.backer_name)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Dispatch thread
-- Due to the large cost incurred by calling the Factorio API to dispatch a
-- train, we want it to happen on its own frame isolated from all other processing.
--------------------------------------------------------------------------------

---@class Cybersyn.Internal.DeliveryDispatchThread: Lib.Thread
---@field public queue (int|string)[] Queue of delivery IDs to be dispatched.
local DeliveryDispatchThread = class("DeliveryDispatchThread", Thread)

function DeliveryDispatchThread:new()
	local thread = Thread.new(self) --[[@as Cybersyn.Internal.DeliveryDispatchThread]]
	thread.friendly_name = "delivery_dispatch"
	-- Guarantee that the thread gets its own exclusive frame.
	thread.workload = 1000000000
	thread.queue = {}
	return thread
end

function DeliveryDispatchThread:main()
	local queue = self.queue
	if #queue == 0 then return self:sleep() end
	-- Pop exactly one delivery and schedule it
	local delivery_id = table.remove(queue, 1)
	local operation = table.remove(queue, 1)
	local delivery = cs2.get_delivery(delivery_id) --[[@as Cybersyn.TrainDelivery?]]
	if not delivery then return end
	delivery[operation](delivery)
	-- Sleep whenever queue is empty.
	if #queue == 0 then return self:sleep() end
end

---@param delivery_id int The ID of the delivery to be dispatched.
---@param operation string The operation to be performed on the delivery.
function DeliveryDispatchThread:enqueue(delivery_id, operation)
	self.queue[#self.queue + 1] = delivery_id
	self.queue[#self.queue + 1] = operation
	self:wake()
end

cs2.on_startup(function()
	-- Create the dispatch thread on startup.
	local thread = DeliveryDispatchThread:new()
	storage.task_ids["delivery_dispatch"] = thread.id
end)

---Defer an operation that will schedule a train onto its own frame.
---@param delivery Cybersyn.TrainDelivery
---@param operation string The method to call on the delivery.
function _G.cs2.enqueue_delivery_operation(delivery, operation)
	local ddt = thread_lib.get_thread(storage.task_ids["delivery_dispatch"]) --[[@as Cybersyn.Internal.DeliveryDispatchThread?]]
	if not ddt then return end
	ddt:enqueue(delivery.id, operation)
end
