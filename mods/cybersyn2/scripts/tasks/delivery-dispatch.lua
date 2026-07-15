local class = require("lib.core.class").class
local cmt_lib = require("lib.core.cmt")
local events = require("lib.core.event")
local strace = require("lib.core.strace")

local tremove = table.remove

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

--------------------------------------------------------------------------------
-- Dispatch thread
-- Due to the large cost incurred by calling the Factorio API to dispatch a
-- train, we want it to happen on its own frame isolated from all other processing.
--------------------------------------------------------------------------------

---@class Cybersyn.Internal.DeliveryDispatchThread: Core.CMT.Task
---@field public queue (int|string)[] Queue of delivery IDs to be dispatched.
local DeliveryDispatchThread = class("DeliveryDispatchThread", cmt_lib.Task)
cs2.DeliveryDispatchThread = DeliveryDispatchThread

function DeliveryDispatchThread:new()
	local thread = cmt_lib.Task.new(self) --[[@as Cybersyn.Internal.DeliveryDispatchThread]]
	thread._cmt_name = "delivery_dispatch"
	thread._cmt_realtime = true
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
	if not delivery then return 1 end
	delivery[operation](delivery)
	-- When performing an operation, be sure to exhaust the workload cap
	return 1000000000
end

events.bind("cs2.threads_start_all", function()
	strace.warn("Starting DeliveryDispatchThread")
	DeliveryDispatchThread:new()
end)
