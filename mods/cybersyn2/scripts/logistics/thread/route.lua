--------------------------------------------------------------------------------
-- `route` logistics phase
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local signal = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local logistics_thread = _G.cs2.logistics_thread
local stop_api = _G.cs2.stop_api
local train_api = _G.cs2.train_api

local max = math.max
local min = math.min
local INF = math.huge
local ceil = math.ceil
local strace = stlib.strace
local TRACE = stlib.TRACE
local DEBUG = stlib.DEBUG
local ERROR = stlib.ERROR
local distsq = _G.cs2.lib.distsq

---@param allocation Cybersyn.Internal.LogisticsAllocation
---@param data Cybersyn.Internal.LogisticsThreadData
---@param train Cybersyn.Train
---@param is_fluid boolean
---@param stack_size uint
local function route_train(data, train, allocation, is_fluid, stack_size)
	local train_capacity = is_fluid and train.fluid_capacity
		or (train.item_slot_capacity * stack_size)
	-- TODO: spillover
end

---@param allocation Cybersyn.Internal.LogisticsAllocation
local function train_score(train, allocation, train_capacity)
	local cap_ratio = min(allocation.qty / train_capacity, 1.0)
	local train_stock = train_api.get_stock(train)
	local stop = (allocation.from --[[@as Cybersyn.TrainStop]]).entity
	local dist = distsq(stop, train_stock)
	return 100 * cap_ratio - dist
end

---@param allocation Cybersyn.Internal.LogisticsAllocation
---@param data Cybersyn.Internal.LogisticsThreadData
local function route_train_allocation(allocation, data)
	if
		(not stop_api.is_valid(allocation.from))
		or (not stop_api.is_valid(allocation.to))
	then
		return
	end
	local is_fluid = signal.key_is_fluid(allocation.item)
	local stack_size = is_fluid and 1 or signal.key_to_stacksize(allocation.item)

	local best_train = nil
	local best_score = -INF
	for _, train in pairs(data.avail_trains) do
		-- Check if still available
		if not train_api.is_free(train) then goto continue end
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
		if
			not (
				stop_api.accepts_layout(allocation.from, train.layout_id)
				and stop_api.accepts_layout(allocation.to, train.layout_id)
			)
		then
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
		return route_train(data, best_train, allocation, is_fluid, stack_size)
	else
		-- TODO: "No train" alert
	end
end

---@param allocation Cybersyn.Internal.LogisticsAllocation
---@param data Cybersyn.Internal.LogisticsThreadData
local function route_allocation(allocation, data)
	-- Skip allocations with qty = 0
	if allocation.qty < 1 then return end
	if allocation.from.type == "stop" then
		return route_train_allocation(allocation, data)
	end
end

--------------------------------------------------------------------------------
-- Loop step lifecycle
--------------------------------------------------------------------------------

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.goto_route(data)
	data.stride = 1
	data.index = 1
	data.state = "route"
end

---@param data Cybersyn.Internal.LogisticsThreadData
local function cleanup_route(data) logistics_thread.goto_next_t(data) end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.route(data)
	cs2.logistics_thread.stride_loop(
		data,
		data.allocations,
		route_allocation,
		function(data2) cleanup_route(data2) end
	)
end
