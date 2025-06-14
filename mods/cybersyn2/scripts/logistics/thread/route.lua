--------------------------------------------------------------------------------
-- `route` logistics phase
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local signal = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local TrainDelivery = _G.cs2.TrainDelivery
local mod_settings = _G.cs2.mod_settings

local empty = tlib.empty
local max = math.max
local min = math.min
local INF = math.huge
local ceil = math.ceil
local strace = stlib.strace
local TRACE = stlib.TRACE
local DEBUG = stlib.DEBUG
local ERROR = stlib.ERROR
local distsq = _G.cs2.lib.distsq
local key_is_fluid = signal.key_is_fluid

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

---@class (exact) Cybersyn.Internal.TrainCargoState
---@field public total_item_slots uint Total item slots. Locked slots already subtracted.
---@field public remaining_item_slots uint Remaining item slots. Locked slots already subtracted.
---@field public fluid_capacity uint Train fluid capacity. Reserved cap already subtracted.
---@field public seen_items table<SignalKey, boolean> Seen items.
---@field public item_spillover uint Per-item spillover from provider PREMULTIPLIED BY NUMBER OF CARGO WAGONS
---@field public fluid_was_allocated boolean True if fluid was allocated.
---@field public manifest SignalCounts Manifest accumulated so far
---@field public spillover SignalCounts? Manifest with spillover included

---@param logistics_thread Cybersyn.LogisticsThread
---@param original_allocation Cybersyn.Internal.LogisticsAllocation
---@param allocation Cybersyn.Internal.LogisticsAllocation
---@param cargo_state Cybersyn.Internal.TrainCargoState
---@return boolean #`true` if should keep trying further allocations.
local function try_allocation(
	logistics_thread,
	original_allocation,
	allocation,
	cargo_state
)
	-- Early-out checks
	-- Abort if no space left
	if
		cargo_state.fluid_capacity < 1 and cargo_state.remaining_item_slots < 1
	then
		return false
	end
	-- Skip already-processed allocations
	if allocation.qty < 1 then return true end
	-- Allocations must have the same "from"
	local from = allocation.from --[[@as Cybersyn.TrainStop]]
	if from.id ~= original_allocation.from.id then return true end
	-- We must not have seen the item yet. This prevents stealing a higher
	-- priority delivery from this "from" to another "to".
	if cargo_state.seen_items[allocation.item] then return true end
	cargo_state.seen_items[allocation.item] = true
	-- Allocations must have the same "to". We must check this after the seen
	-- item check.
	if allocation.to.id ~= original_allocation.to.id then return true end
	-- Honor "ignore secondary thresholds"
	local from_thresh = allocation.from_thresh
	local to_thresh = allocation.to_thresh
	if
		(allocation ~= original_allocation) and from.ignore_secondary_thresholds
	then
		from_thresh = 1
		to_thresh = 1
	end

	-- Fluid case
	if allocation.is_fluid then
		-- No mixing fluid
		if cargo_state.fluid_was_allocated or cargo_state.fluid_capacity < 1 then
			return true
		end
		-- Verify capacity
		if
			cargo_state.fluid_capacity >= from_thresh
			and cargo_state.fluid_capacity >= to_thresh
		then
			-- Allocate fluid
			cargo_state.fluid_was_allocated = true
			-- TODO: mixin available `from` inventory
			local amt = min(allocation.qty, cargo_state.fluid_capacity)
			cargo_state.fluid_capacity = 0
			if amt > 0 then
				cargo_state.manifest[allocation.item] = amt
				if cargo_state.spillover then
					cargo_state.spillover[allocation.item] = amt
				end
			end
			-- Refund and clear allocation
			logistics_thread:refund_allocation(allocation)
		end
		return true
	end

	-- Solid case
	local remaining_item_slots = cargo_state.remaining_item_slots
	if remaining_item_slots < 1 then return true end
	local stack_size = allocation.stack_size
	local spillover = cargo_state.item_spillover
	-- TODO: locked slots and spillover should not count against receiver
	-- threshold.
	-- Allow grace for locked slots on receiver threshold
	to_thresh =
		min(to_thresh, cargo_state.total_item_slots * allocation.stack_size)
	-- Figure out the most we could put on to the train, accounting for spillover
	-- and remaining slots. If below threshold, abort.
	local remaining_item_capacity = (remaining_item_slots * stack_size)
		- spillover
	if
		remaining_item_capacity < from_thresh
		or remaining_item_capacity < to_thresh
	then
		return true
	end
	-- Compute manifest and spillover
	-- TODO: mixin available `from` inventory
	local manifest_qty = min(allocation.qty, remaining_item_capacity)
	local spillover_qty = min(allocation.qty + spillover, remaining_item_capacity)
	local slots_needed = ceil(spillover_qty / stack_size)
	if slots_needed > remaining_item_slots then return true end
	cargo_state.remaining_item_slots = remaining_item_slots - slots_needed
	cargo_state.manifest[allocation.item] = manifest_qty
	if spillover > 0 then
		if not cargo_state.spillover then cargo_state.spillover = {} end
		cargo_state.spillover[allocation.item] = spillover_qty
	end
	logistics_thread:refund_allocation(allocation)
	return true
end

---@param allocation Cybersyn.Internal.LogisticsAllocation
---@param data Cybersyn.LogisticsThread
---@param train Cybersyn.Train
---@return boolean
local function route_train(data, train, allocation, index)
	local n_cargo_wagons, n_fluid_wagons = train:get_wagon_counts()
	local from = allocation.from --[[@as Cybersyn.TrainStop]]
	local reserved_slots = from.reserved_slots or 0
	local reserved_capacity = from.reserved_capacity or 0
	local spillover = from.spillover or 0

	local total_item_slots =
		max(train.item_slot_capacity - (n_cargo_wagons * reserved_slots), 0)
	---@type Cybersyn.Internal.TrainCargoState
	local cargo_state = {
		total_item_slots = total_item_slots,
		remaining_item_slots = total_item_slots,
		fluid_capacity = max(
			train.fluid_capacity - (n_fluid_wagons * reserved_capacity),
			0
		),
		item_spillover = spillover * n_cargo_wagons,
		fluid_was_allocated = false,
		seen_items = {},
		manifest = {},
	}

	local allocations_from = data.allocs_from[from.id]
	if not allocations_from then
		strace(
			stlib.ERROR,
			"cs2",
			"route",
			"message",
			"Inconsistent logistics thread state (alloc without alloc_from)"
		)
		return false
	end

	-- Attempt to tack on as many future point-to-point allocations as possible
	local found_self = false
	for i = 1, #allocations_from do
		local future_alloc = allocations_from[i]
		if future_alloc == allocation then found_self = true end
		if not found_self then goto continue end
		if not try_allocation(data, allocation, future_alloc, cargo_state) then
			break
		end
		if from.produce_single_item then
			-- If we are producing a single item, we can stop after the
			-- primary allocation completes.
			break
		end
		::continue::
	end

	-- Verify that we have a manifest
	-- XXX: debug, remove after we know this all works
	local mi1, mq1 = next(cargo_state.manifest)
	if (not mi1) or (mq1 < 1) then
		strace(
			stlib.ERROR,
			"cs2",
			"route",
			"message",
			"tried to route a train with an empty manifest"
		)
		return false
	end

	-- Mark consumer as receiving a delivery
	allocation.to.last_consumed_tick[allocation.item] = game.tick
	-- Remove from avail_trains
	data.avail_trains[train.id] = nil
	-- Create delivery
	TrainDelivery.new(
		train,
		allocation.from --[[@as Cybersyn.TrainStop]],
		allocation.from_inv,
		allocation.to --[[@as Cybersyn.TrainStop]],
		allocation.to_inv,
		cargo_state.manifest,
		cargo_state.spillover or cargo_state.manifest, -- source charge
		spillover,
		reserved_slots,
		reserved_capacity
	)
	return true
end

---@param train Cybersyn.Train
---@param allocation Cybersyn.Internal.LogisticsAllocation
---@return number
local function train_score(train, allocation, train_capacity)
	-- TODO: re-evaluate this, ideal cap ratio is 1.0, and above 1.0 should
	-- be treated more harshly than below 1.0
	-- note: route_train_allocation already assures train_capacity>0
	local cap_ratio = min(allocation.qty / train_capacity, 1.0)
	local train_stock = train:get_stock()
	local stop = (allocation.from --[[@as Cybersyn.TrainStop]]).entity
	local dist = distsq(stop, train_stock)
	return 100 * cap_ratio - dist
end

---@param allocation Cybersyn.Internal.LogisticsAllocation
function LogisticsThread:route_train_allocation(allocation, index)
	-- If alloc below threshold, skip it.
	if
		allocation.qty < allocation.from_thresh
		or allocation.qty < allocation.to_thresh
	then
		-- TODO: log at provider that stuff was reserved below threshold
		return false
	end

	local from = allocation.from --[[@as Cybersyn.TrainStop]]
	local to = allocation.to --[[@as Cybersyn.TrainStop]]
	if (not from:is_valid()) or (not to:is_valid()) then return false end

	-- Don't queue into a full queue.
	if from:is_queue_full() then return false end

	local is_fluid = allocation.is_fluid
	local stack_size = allocation.stack_size

	local avail_trains = self.avail_trains or empty
	local best_train = nil
	local best_score = -INF
	for train_id, train in pairs(avail_trains) do
		-- Check if still available
		if not train:is_available() then
			avail_trains[train_id] = nil
			goto continue
		end
		-- Check if capacity exceeds both thresholds
		local train_capacity = is_fluid and train.fluid_capacity
			or (train.item_slot_capacity * stack_size)
		if
			train_capacity < 1
			or train_capacity < allocation.from_thresh
			or train_capacity < allocation.to_thresh
		then
			goto continue
		end
		-- Check if allowlisted at both ends
		if not (from:allows_train(train) and to:allows_train(train)) then
			goto continue
		end
		-- Check if better than the previous train.
		local score = train_score(train, allocation, train_capacity)
		if score > best_score then
			best_train = train
			best_score = score
		end
		::continue::
	end

	if best_train then
		return route_train(self, best_train, allocation, index)
	else
		-- TODO: "No train found" alert
		return false
	end
end

---@param allocation Cybersyn.Internal.LogisticsAllocation
function LogisticsThread:route_allocation(allocation, index)
	if allocation.from.type == "stop" then
		return self:route_train_allocation(allocation, index)
	end
end

---@param allocation Cybersyn.Internal.LogisticsAllocation
function LogisticsThread:maybe_route_allocation(allocation, index)
	-- Skip allocations with qty = 0
	if allocation.qty < 1 then return end
	-- If can't route allocation, zero and refund it
	if not self:route_allocation(allocation, index) then
		self:refund_allocation(allocation)
	end
end

function LogisticsThread:enter_route()
	local top_id = self.topology_id
	self.avail_trains = tlib.t_map_t(storage.vehicles, function(_, veh)
		if veh.type == "train" and veh.topology_id == top_id then
			return veh.id, veh
		end
	end) --[[@as table<uint, Cybersyn.Train>]]
	self:begin_async_loop(self.allocations, 1)
end

function LogisticsThread:exit_route() self.allocations = nil end

function LogisticsThread:route()
	self:step_async_loop(
		self.maybe_route_allocation,
		function(x) x:set_state("init") end
	)
end
