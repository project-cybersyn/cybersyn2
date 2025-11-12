--------------------------------------------------------------------------------
-- `route` logistics phase
--------------------------------------------------------------------------------

local tlib = require("lib.core.table")
local stlib = require("lib.core.strace")
local signal = require("lib.signal")
local cs2 = _G.cs2
local TrainDelivery = _G.cs2.TrainDelivery
local mod_settings = _G.cs2.mod_settings

local empty = tlib.empty
local max = math.max
local min = math.min
local sqrt = math.sqrt
local INF = math.huge
local ceil = math.ceil
local strace = stlib.strace
local TRACE = stlib.TRACE
local DEBUG = stlib.DEBUG
local ERROR = stlib.ERROR
local dist = _G.cs2.lib.dist
local key_is_fluid = signal.key_is_fluid

local route_plugins = prototypes.mod_data["cybersyn2"].data.route_plugins --[[@as {[string]: Cybersyn2.RoutePlugin} ]]

local reachable_callbacks = tlib.t_map_a(
	route_plugins or {},
	function(plugin) return plugin.reachable_callback end
) --[[@as Core.RemoteCallbackSpec[] ]]

local function query_reachable_callbacks(...)
	for _, callback in pairs(reachable_callbacks) do
		if callback then
			local result = remote.call(callback[1], callback[2], ...)
			if result then return result end
		end
	end
end

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

---@class (exact) Cybersyn.Internal.TrainCargoState
---@field public base_item_slots uint Base item slots. Before locked slots are subtracted.
---@field public total_item_slots uint Total item slots. Locked slots already subtracted.
---@field public remaining_item_slots uint Remaining item slots. Locked slots already subtracted.
---@field public base_fluid_capacity uint Base fluid capacity. Before reserved cap is subtracted.
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
	if allocation ~= original_allocation then
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
			cargo_state.base_fluid_capacity >= from_thresh
			and cargo_state.base_fluid_capacity >= to_thresh
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

	local base_item_slots = train.item_slot_capacity
	local total_item_slots =
		max(base_item_slots - (n_cargo_wagons * reserved_slots), 0)
	---@type Cybersyn.Internal.TrainCargoState
	local cargo_state = {
		base_item_slots = base_item_slots,
		total_item_slots = total_item_slots,
		remaining_item_slots = total_item_slots,
		base_fluid_capacity = train.fluid_capacity,
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
		if mod_settings.debug then
			local log_entry = {
				type = "ALLOC_COULDNT_ROUTE",
				from = allocation.from.id,
				to = allocation.to.id,
				item = allocation.item,
				qty = allocation.qty,
			}
			cs2.ring_buffer_log_write(allocation.from, log_entry)
			cs2.ring_buffer_log_write(allocation.to, log_entry)
		end

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
	local delivery = TrainDelivery.new(
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
	if mod_settings.debug then
		local log_entry = {
			type = "ROUTE_TRAIN",
			from = allocation.from.id,
			to = allocation.to.id,
			item = allocation.item,
			qty = allocation.qty,
			delivery = delivery.id,
		}
		cs2.ring_buffer_log_write(allocation.from, log_entry)
		cs2.ring_buffer_log_write(allocation.to, log_entry)
	end
	return true
end

---Determine a numerical score for a train processing a given allocation.
---This score is used to determine the best train for the allocation.
---@param train Cybersyn.Train
---@param allocation Cybersyn.Internal.LogisticsAllocation
---@return number
local function train_score(train, allocation, train_capacity)
	-- Prefer trains that can move the most material.
	local material_moved = min(allocation.qty, train_capacity)
	-- Amongst those trains, prefer those that use the most of their capacity.
	local cap_ratio = min(allocation.qty / train_capacity, 1.0)
	-- Amongst the best-fitting trains, penalize those that are further away
	local train_stock = train:get_stock()
	if not train_stock then return -math.huge end
	local stop = (allocation.from --[[@as Cybersyn.TrainStop]]).entity --[[@as LuaEntity]]
	local dx = dist(stop, train_stock)

	return (10000 * material_moved) + (1000 * cap_ratio) - dx
end

---Route an allocation via train, if possible.
---@param allocation Cybersyn.Internal.LogisticsAllocation
function LogisticsThread:route_train_allocation(allocation, index)
	local qty = allocation.qty
	-- Allocation with qty=0 was already handled elsewhere.
	if qty < 1 then return false end

	-- Don't route allocations below threshold.
	if qty < allocation.from_thresh then
		if mod_settings.debug then
			local log_entry = {
				type = "ALLOC_BELOW_FROM_THRESH",
				from = allocation.from.id,
				to = allocation.to.id,
				item = allocation.item,
				qty = qty,
			}
			cs2.ring_buffer_log_write(allocation.from, log_entry)
			cs2.ring_buffer_log_write(allocation.to, log_entry)
		end
		return false
	end
	if qty < allocation.to_thresh then
		if mod_settings.debug then
			local log_entry = {
				type = "ALLOC_BELOW_TO_THRESH",
				from = allocation.from.id,
				to = allocation.to.id,
				item = allocation.item,
				qty = qty,
			}
			cs2.ring_buffer_log_write(allocation.from, log_entry)
			cs2.ring_buffer_log_write(allocation.to, log_entry)
		end
		return false
	end

	local from = allocation.from --[[@as Cybersyn.TrainStop]]
	local to = allocation.to --[[@as Cybersyn.TrainStop]]
	if (not from:is_valid()) or (not to:is_valid()) then return false end

	-- Don't queue into a full queue.
	if from:is_queue_full() then
		if mod_settings.debug then
			cs2.ring_buffer_log_write(from, {
				type = "FROM_QUEUE_FULL",
				from = from.id,
				to = to.id,
				item = allocation.item,
				qty = qty,
			})
		end
		return false
	end

	local is_fluid = allocation.is_fluid
	local stack_size = allocation.stack_size

	local avail_trains = self.avail_trains or empty
	local best_train = nil
	local best_score = -INF
	local n_trains_considered, busy_rejections, capacity_threshold_rejections, allowlist_rejections =
		0, 0, 0, 0
	for train_id, train in pairs(avail_trains) do
		n_trains_considered = n_trains_considered + 1

		-- Check if still available
		if not train:is_available() then
			avail_trains[train_id] = nil
			busy_rejections = busy_rejections + 1
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
			capacity_threshold_rejections = capacity_threshold_rejections + 1
			goto continue
		end
		-- Check if allowlisted at both ends
		if not (from:allows_train(train) and to:allows_train(train)) then
			allowlist_rejections = allowlist_rejections + 1
			goto continue
		end
		-- Check if any plugin vetoes reachability
		if
			query_reachable_callbacks(
				train.id,
				from.id,
				to.id,
				train:get_stock(),
				train.home_surface_index,
				from.entity,
				to.entity
			)
		then
			-- TODO: counting plugin rejection as an allowlist rejection for now...
			allowlist_rejections = allowlist_rejections + 1
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
		if mod_settings.debug then
			local log_entry = {
				type = "ALLOC_NO_AVAIL_TRAIN",
				from = from.id,
				to = to.id,
				item = allocation.item,
				qty = qty,
				n_trains_considered = n_trains_considered,
				busy_rejections = busy_rejections,
				capacity_threshold_rejections = capacity_threshold_rejections,
				allowlist_rejections = allowlist_rejections,
			}
			cs2.ring_buffer_log_write(from, log_entry)
			cs2.ring_buffer_log_write(to, log_entry)
		end
		return false
	end
end

---Handle routing a single allocation.
---@param allocation Cybersyn.Internal.LogisticsAllocation
---@return boolean #`true` if allocation was routed, `false` if it should be refunded.
function LogisticsThread:route_allocation(allocation, index)
	if allocation.from.type == "stop" then
		return self:route_train_allocation(allocation, index)
	end
	return false
end

---Handle routing of a single allocation, refunding it if it can't
---be routed.
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
	-- Initial set of available trains = all trains associated with
	-- this topology.
	self.avail_trains = tlib.t_map_t(storage.vehicles, function(_, veh)
		if veh.type == "train" and veh.topology_id == top_id then
			return veh.id, veh
		end
	end) --[[@as table<uint, Cybersyn.Train>]]

	self:begin_async_loop(
		self.allocations,
		math.ceil(cs2.PERF_ROUTE_WORKLOAD * mod_settings.work_factor)
	)
end

function LogisticsThread:exit_route() self.allocations = nil end

function LogisticsThread:route()
	self:step_async_loop(
		self.maybe_route_allocation,
		function(x) x:set_state("init") end
	)
end
