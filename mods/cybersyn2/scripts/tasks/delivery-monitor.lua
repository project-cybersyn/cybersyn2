local class = require("lib.core.class").class
local cmt = require("lib.core.cmt")
local tasks = require("scripts.tasks.base")
local strace = require("lib.core.strace")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local era_lib = require("lib.core.math.era-counter")

local add_workload = tasks.add_workload
local pairs = pairs

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

--------------------------------------------------------------------------------
-- Delivery monitor thread
--
-- Clears expired completed deliveries from storage and warns about deliveries
-- that may be taking too long to complete.
--------------------------------------------------------------------------------

---@class Cybersyn.Internal.DeliveryMonitor: StatefulTask
---@field state "init"|"enum_deliveries" State of the task.
local DeliveryMonitor = class("DeliveryMonitor", cs2.StatefulTask)

function DeliveryMonitor:new()
	local thread = cs2.StatefulTask.new(self) --[[@as Cybersyn.Internal.DeliveryMonitor]]
	thread._cmt_name = "delivery_monitor"
	thread._cmt_work_cap = 5
	thread.state = "init"
	cmt.add(thread)
	cmt.wake(thread)
	return thread
end

function DeliveryMonitor:init()
	if game then self:set_state("enum_deliveries") end
end

function DeliveryMonitor:enter_enum_deliveries()
	self:begin_async_loop(tlib.keys(storage.deliveries), 1)
end

function DeliveryMonitor:enum_delivery(delivery_id)
	local delivery = cs2.get_delivery(delivery_id, true)
	if not delivery then return end
	local is_finalized = delivery:is_in_final_state()

	-- Destroy expired deliveries.
	if
		is_finalized
		and (
			not delivery.state_tick
			or delivery.state_tick < game.tick - cs2.DELIVERY_EXPIRATION_TICKS
		)
	then
		return delivery:destroy()
	end

	-- Check stuck deliveries
	if not is_finalized then delivery:check_stuck(self.workload_counter) end

	add_workload(self.workload_counter, 2)
end

function DeliveryMonitor:enum_deliveries()
	self:step_async_loop(
		self.enum_delivery,
		function(thr) thr:set_state("init") end
	)
end

function DeliveryMonitor:exit_enum_deliveries() self.delivery_ids = nil end

-- Start delivery monitor thread on startup.
events.bind("cs2.threads_start_all", function()
	strace.warn("Starting DeliveryMonitor thread")
	DeliveryMonitor:new()
end)
