--------------------------------------------------------------------------------
-- Green threading/coroutine library for Factorio
--------------------------------------------------------------------------------

if ... ~= "__cybersyn2__.lib.thread" then
	return require("__cybersyn2__.lib.thread")
end

local class = require("__cybersyn2__.lib.class").class
local counters = require("__cybersyn2__.lib.counters")

local table_size = _G.table_size
local BIG_INT = 9007199254740000

local DEFAULT_MAX_WORKLOAD = 100
local DEFAULT_MAX_BUCKET_SIZE = 5
local DEFAULT_RESCHEDULE_INTERVAL = 6000

local lib = {}

local strace = nil
local ERROR = 60
local WARN = 50
local TRACE = 10

---Set strace handler. `nil` disables tracing entirely.
---@param handler? fun(level: int, ...)
function lib.set_strace_handler(handler) strace = handler end

--------------------------------------------------------------------------------
-- Types/Data
--------------------------------------------------------------------------------

---@alias Lib.Thread.IdSet {[integer]: true}

---Storage table for threads.
---@class Lib.Thread.Storage
---@field public threads {[integer]: Lib.Thread} All threads by id.
---@field public max_workload number Empirical target workload per execution cycle. Used to determine how many threads should fit into a frame window.
---@field public max_bucket_size uint Maximum number of threads that can be scheduled in a single frame, regardless of work_per_frame calculations. Used to prevent degeneracy when work_per_frame is inaccurate.
---@field public buckets Lib.Thread.IdSet[] Active threads, bucketed by frame.
---@field public bucket_workloads number[] Workload of each bucket.
---@field public current_bucket uint The current bucket being processed.
---@field public wake_at {[uint]: Lib.Thread.IdSet} Threads that are scheduled to wake up at a given tick.
---@field public last_reschedule_tick uint The tick at which the last reschedule occurred.

---Initialize the threads system. Must be called in the mod's `on_init` handler.
function lib.init()
	---@type Lib.Thread.Storage
	local initial_storage = {
		threads = {},
		max_workload = DEFAULT_MAX_WORKLOAD,
		max_bucket_size = DEFAULT_MAX_BUCKET_SIZE,
		buckets = { {} },
		bucket_workloads = { 0 },
		current_bucket = 1,
		wake_at = {},
		last_reschedule_tick = 0,
	}
	storage._thread = initial_storage
end

---@return Lib.Thread.Storage
local function get_data()
	---@diagnostic disable-next-line: undefined-field
	return storage._thread
end

---@class Lib.Thread
---@field public id integer Unique ID of the thread
---@field public friendly_name? string Friendly name of the thread, used for debugging and logging
---@field public wake_at? integer The tick at which the thread should wake up. If `nil`, the thread is not sleeping.
---@field public workload? number Empirical measure of work done by this thread per execution cycle. Used to determine how many threads should fit into a frame window.
local Thread = class()
lib.Thread = Thread

--------------------------------------------------------------------------------
-- Scheduler
--------------------------------------------------------------------------------

---@param data Lib.Thread.Storage
local function recompute_workload(data, bucket, bucket_index)
	local workload = 0
	for id in pairs(bucket) do
		local thread = data.threads[id]
		if thread and not thread.wake_at then
			workload = workload + (thread.workload or 0)
		end
	end
	data.bucket_workloads[bucket_index] = workload
end

---@param data Lib.Thread.Storage
local function reschedule_all(data)
	local buckets = { {} }
	local bucket_workloads = { 0 }
	local current_bucket = 1
	local max_workload = data.max_workload
	local max_bucket_size = data.max_bucket_size
	for id, thread in pairs(data.threads) do
		-- Skip sleeping threads
		if thread.wake_at then goto continue end
		-- Add a new bucket if needed
		local bucket = buckets[current_bucket]
		local workload = bucket_workloads[current_bucket]
		local thread_workload = thread.workload or 0
		local next_workload = workload + thread_workload
		if
			next_workload > max_workload or table_size(bucket) >= max_bucket_size
		then
			current_bucket = current_bucket + 1
			bucket = {}
			workload = 0
			next_workload = thread_workload
			buckets[current_bucket] = bucket
		end
		-- Add the thread to the bucket
		bucket[id] = true
		bucket_workloads[current_bucket] = next_workload
		::continue::
	end
	data.buckets = buckets
	data.bucket_workloads = bucket_workloads
	data.current_bucket = 1
end

---@param data Lib.Thread.Storage
---@param thread Lib.Thread
---@param use_current_bucket boolean? If `true`, the thread will be scheduled in the current bucket if possible.
local function schedule(data, thread, use_current_bucket)
	if thread.wake_at then return end
	local buckets = data.buckets
	local n_buckets = #buckets
	local bucket_workloads = data.bucket_workloads
	local thread_workload = thread.workload or 0
	local max_workload = data.max_workload
	local max_bucket_size = data.max_bucket_size
	local current_bucket = data.current_bucket
	local offset = use_current_bucket and -2 or -1
	-- Try to fit thread into existing buckets
	for i = 1, n_buckets do
		local bucket_index = ((current_bucket + offset + i) % n_buckets) + 1
		local bucket = buckets[bucket_index]
		local workload = bucket_workloads[bucket_index]
		local next_workload = workload + thread_workload
		if
			next_workload <= max_workload and table_size(bucket) < max_bucket_size
		then
			bucket[thread.id] = true
			bucket_workloads[bucket_index] = next_workload
			return
		end
	end
	-- Add a new bucket if we couldn't find a suitable one
	buckets[n_buckets + 1] = { [thread.id] = true }
	bucket_workloads[n_buckets + 1] = thread_workload
end

---@param data Lib.Thread.Storage
---@param id integer
---@param bucket Lib.Thread.IdSet?
---@param bucket_index integer
local function unschedule(data, id, bucket, bucket_index)
	bucket[id] = nil
	return recompute_workload(data, bucket, bucket_index)
end

--------------------------------------------------------------------------------
-- Executive
--------------------------------------------------------------------------------

---Perform tasks for the given tick. MUST be called precisely once every tick by the `on_nth_tick(1)` handler.
---@param tick_data NthTickEventData
function lib.tick(tick_data)
	local data = get_data()
	if not data then
		if strace then strace(ERROR, "thread", "missing_data") end
		return
	end
	local tick_n = tick_data.tick

	-- Wake all threads that are scheduled to wake up at this tick
	local wake_now = data.wake_at[tick_n]
	if wake_now then
		for id in pairs(wake_now) do
			local thread = data.threads[id]
			if thread then
				thread.wake_at = nil
				schedule(data, thread, true)
			end
		end
		data.wake_at[tick_n] = nil
	end

	-- Execute all mainloops in current bucket.
	local buckets = data.buckets
	local current_bucket = data.current_bucket
	local bucket = buckets[current_bucket]
	if not bucket then
		-- Something has mutilated the thread scheduler's state.
		error("Thread scheduler: missing bucket, invalid state")
		return
	end
	for id in pairs(bucket) do
		local thread = data.threads[id]
		if thread then
			if thread.wake_at then
				unschedule(data, id, bucket, current_bucket)
			else
				thread:main()
			end
		else
			-- Thread has been killed, remove from bucket
			unschedule(data, id, bucket, current_bucket)
		end
	end

	-- Move to next bucket.
	current_bucket = current_bucket + 1
	if current_bucket > #buckets then
		-- If we haven't rescheduled all in a while, do so at the end of a bucket
		-- sweep so no one is denied a timeslice.
		if data.last_reschedule_tick + DEFAULT_RESCHEDULE_INTERVAL < tick_n then
			data.last_reschedule_tick = tick_n
			reschedule_all(data)
		end
		current_bucket = 1
	end
	data.current_bucket = current_bucket
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

---Create a new thread with the given handler. The thread is started in a
---sleeping state.
function Thread:new()
	local id = counters.next("_thread")
	local thread = setmetatable({
		id = id,
		wake_at = BIG_INT,
	}, self) --[[@as Lib.Thread]]
	local data = get_data()
	data.threads[id] = thread
	return thread
end

---@param data Lib.Thread.Storage
local function do_sleep_until(data, thread, tick)
	local id = thread.id
	thread.wake_at = tick
	if tick < BIG_INT then
		local wake_at = data.wake_at[tick]
		if not wake_at then
			data.wake_at[tick] = { [id] = true }
		else
			wake_at[id] = true
		end
	end
end

---Sleep the thread for the given number of ticks. Note that sleeping is inexact
---and the thread may not run on the exact wakeup tick.
---@param ticks uint The number of ticks to sleep for. If `0`, the thread will not sleep.
function Thread:sleep_for(ticks)
	if ticks <= 0 then return end
	local sleep_until = game.tick + ticks
	return do_sleep_until(get_data(), self, sleep_until)
end

---Sleep the thread until the given tick. Note that sleeping is inexact and the
---thread may not run on the exact wakeup tick.
---@param tick uint The tick at which to wake up. If not in the future, the thread will not sleep.
function Thread:sleep_until(tick)
	if tick <= game.tick then return end
	return do_sleep_until(get_data(), self, tick)
end

---Sleep the thread forever or until manually woken up.
function Thread:sleep() return do_sleep_until(get_data(), self, BIG_INT) end

---Wake a sleeping thread. This will not wake the thread if it is already awake.
function Thread:wake()
	local wake_at = self.wake_at
	if not wake_at then return end
	local data = get_data()
	-- Clear wakeup schedule if needed
	if wake_at < BIG_INT then
		local wake_now = data.wake_at[wake_at]
		if wake_now then wake_now[self.id] = nil end
	end
	-- Schedule the thread.
	return schedule(data, self, false)
end

---Kill the thread, preventing it from ever running its handler again.
function Thread:kill() get_data().threads[self.id] = nil end

---Thread main loop. Override in a subclass to perform work.
function Thread:main() end

---Get a thread by ID. Returns `nil` if the thread does not exist or has been killed.
---@param id integer The ID of the thread to get.
---@return Lib.Thread? #The thread with the given ID, or `nil` if it does not exist.
function lib.get_thread(id)
	local data = get_data()
	return data and data.threads[id]
end

---Get all thread IDs. Returns an empty table if no threads exist.
---@return integer[] #A list of all thread IDs.
function lib.get_thread_ids()
	local data = get_data()
	if not data then return {} end
	local ids = {}
	for id in pairs(data.threads) do
		ids[#ids + 1] = id
	end
	return ids
end

return lib
