local class = require("lib.core.class").class
local cmt_lib = require("lib.core.cmt")
local events = require("lib.core.event")
local strace = require("lib.core.strace")
local era_lib = require("lib.core.math.era-counter")

local tremove = table.remove

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

--------------------------------------------------------------------------------
-- Dispatch thread
-- Due to the large cost incurred by calling the Factorio API to dispatch a
-- train, we want it to happen on its own frame isolated from all other processing.
--------------------------------------------------------------------------------

---@class Cybersyn.Internal.DeliveryDispatchThread: Core.CMT.Task
---@field public n_dispatches int64 The number of dispatches performed by this thread
---@field public last_dispatch_tick? int64 The tick of the last dispatch performed by this thread
---@field public frames_per_dispatch Core.EraCounter The number of frames between dispatches performed by this thread
local DeliveryDispatchThread = class("DeliveryDispatchThread", cmt_lib.Task)
cs2.DeliveryDispatchThread = DeliveryDispatchThread

function DeliveryDispatchThread:new()
	local thread = cmt_lib.Task.new(self) --[[@as Cybersyn.Internal.DeliveryDispatchThread]]
	thread._cmt_name = "delivery_dispatch"
	thread._cmt_realtime = true
	thread._cmt_work_cap = 5
	thread.n_dispatches = 0
	thread.frames_per_dispatch = era_lib.create_era_counter(0)
	cmt_lib.add(thread)
	cmt_lib.wake(thread)
	return thread
end

function DeliveryDispatchThread:main()
	local queue = storage.dispatch_queue
	if #queue == 0 then return 0 end
	-- Pop exactly one delivery and schedule it
	local delivery_id = tremove(queue, 1) --[[@as Id]]
	local operation = tremove(queue, 1) --[[@as string]]
	local delivery = cs2.get_delivery(delivery_id)
	if not delivery then
		strace.warn(
			"Dispatch thread: skipping because Delivery not found",
			delivery_id
		)
		return 1
	end
	local ldt = self.last_dispatch_tick
	local t = game.tick
	if ldt then
		local fpd = self.frames_per_dispatch
		if not fpd then
			fpd = era_lib.create_era_counter(0)
			self.frames_per_dispatch = fpd
		end
		era_lib.update_era_counter(fpd, t - ldt)
	end
	self.last_dispatch_tick = t
	self.n_dispatches = (self.n_dispatches or 0) + 1
	delivery[operation](delivery)
	-- When performing an operation, be sure to exhaust the workload cap
	cmt_lib.yield(self)
	return 1000000000
end

events.bind("cs2.threads_start_all", function()
	strace.warn("Starting DeliveryDispatchThread")
	DeliveryDispatchThread:new()
end)
