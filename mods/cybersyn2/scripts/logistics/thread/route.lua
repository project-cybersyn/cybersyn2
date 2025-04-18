--------------------------------------------------------------------------------
-- `route` logistics phase
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local signal = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local TrainDelivery = _G.cs2.TrainDelivery

local max = math.max
local min = math.min
local INF = math.huge
local ceil = math.ceil
local strace = stlib.strace
local TRACE = stlib.TRACE
local DEBUG = stlib.DEBUG
local ERROR = stlib.ERROR
local distsq = _G.cs2.lib.distsq

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

---@param allocation Cybersyn.Internal.LogisticsAllocation
---@param data Cybersyn.LogisticsThread
---@param train Cybersyn.Train
---@param is_fluid boolean
---@param stack_size uint
local function route_train(data, train, allocation, is_fluid, stack_size)
	-- TODO: locked slots subtract from effective cap here
	local train_capacity = is_fluid and train.fluid_capacity
		or (train.item_slot_capacity * stack_size)
	-- TODO: spillover
	local manifest = { [allocation.item] = min(allocation.qty, train_capacity) }
	-- TODO: Tackons
	-- Refund and clear allocation
	data:refund_allocation(allocation)
	allocation.qty = 0
	-- Mark consumer as receiving a delivery
	allocation.to.last_consumer_tick = game.tick
	-- Remove from avail_trains
	data.avail_trains[train.id] = nil
	-- Create delivery
	TrainDelivery.new(
		train,
		allocation.from --[[@as Cybersyn.TrainStop]],
		allocation.from_inv,
		allocation.to --[[@as Cybersyn.TrainStop]],
		allocation.to_inv,
		manifest,
		manifest -- source charge
	)
end

---@param train Cybersyn.Train
---@param allocation Cybersyn.Internal.LogisticsAllocation
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
function LogisticsThread:route_train_allocation(allocation)
	local from = allocation.from --[[@as Cybersyn.TrainStop]]
	local to = allocation.to --[[@as Cybersyn.TrainStop]]
	if (not from:is_valid()) or (not to:is_valid()) then
		self:refund_allocation(allocation)
		allocation.qty = 0
		return
	end

	-- TODO: make sure from station still has enough. spillover from
	-- a previous delivery may have changed things.

	local is_fluid = signal.key_is_fluid(allocation.item)
	local stack_size = is_fluid and 1
		or (signal.key_to_stacksize(allocation.item) or 1)

	local best_train = nil
	local best_score = -INF
	for train_id, train in pairs(self.avail_trains) do
		-- Check if still available
		if not train:is_available() then
			self.avail_trains[train_id] = nil
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
		return route_train(self, best_train, allocation, is_fluid, stack_size)
	else
		-- TODO: "No train" alert
		self:refund_allocation(allocation)
		allocation.qty = 0
	end
end

---@param allocation Cybersyn.Internal.LogisticsAllocation
function LogisticsThread:route_allocation(allocation)
	-- Skip allocations with qty = 0
	if allocation.qty < 1 then return end
	if allocation.from.type == "stop" then
		return self:route_train_allocation(allocation)
	end
end

function LogisticsThread:enter_route()
	self.stride = 1
	self.index = 1
end

function LogisticsThread:route()
	self:async_loop(
		self.allocations,
		self.route_allocation,
		function(x) x:set_state("next_t") end
	)
end
