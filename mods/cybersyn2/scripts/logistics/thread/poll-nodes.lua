--------------------------------------------------------------------------------
-- poll_nodes phase
-- Step over nodes in a topology, updating state variables from combinator
-- inputs and adding their items to the logistics arrays.
--------------------------------------------------------------------------------

local stlib = require("__cybersyn2__.lib.strace")
local tlib = require("__cybersyn2__.lib.table")
local slib = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings
local combinator_settings = _G.cs2.combinator_settings

local strace = stlib.strace
local TRACE = stlib.TRACE
local WARN = stlib.WARN

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

---@param logistics_type "providers" | "pushers" | "pullers" | "sinks"
---@param node Cybersyn.Node
---@param item SignalKey
function LogisticsThread:add_to_logisics_set(logistics_type, node, item)
	local nodes = self[logistics_type][item]
	if not nodes then
		nodes = {}
		self[logistics_type][item] = nodes
	end
	nodes[node.id] = true
end

---@param logistics_type "providers" | "pushers" | "pullers" | "sinks"
---@param node_id Id
---@param item SignalKey
function LogisticsThread:is_in_logistics_set(logistics_type, node_id, item)
	local set = self[logistics_type][item]
	return set and set[node_id]
end

---@param logistics_type "providers" | "pushers" | "pullers" | "sinks"
---@param node_id Id
---@param item SignalKey
function LogisticsThread:remove_from_logistics_set(
	logistics_type,
	node_id,
	item
)
	local set = self[logistics_type][item]
	if set then set[node_id] = nil end
end

---@param stop Cybersyn.TrainStop
function LogisticsThread:classify_inventory(stop)
	local inventory = stop:get_inventory()
	if not inventory then return end
	if stop.is_producer then
		inventory:foreach_producible_item(function(item, provide_qty, push_qty)
			local _, out_t = stop:get_delivery_thresholds(item)
			if provide_qty >= out_t then
				self:add_to_logisics_set("providers", stop, item)
				self.seen_cargo[item] = true
			end
			if push_qty >= out_t then
				self:add_to_logisics_set("pushers", stop, item)
				self.seen_cargo[item] = true
			end
		end)
	end
	if stop.is_consumer then
		inventory:foreach_consumable_item(function(item, pull_qty, sink_qty)
			local in_t = stop:get_delivery_thresholds(item)
			if pull_qty >= in_t then
				self:add_to_logisics_set("pullers", stop, item)
				self.seen_cargo[item] = true
			end
			if sink_qty >= in_t then
				self:add_to_logisics_set("sinks", stop, item)
				self.seen_cargo[item] = true
			end
		end)
	end
end

---@param stop Cybersyn.TrainStop
function LogisticsThread:poll_train_stop_station_comb(stop)
	local combs = stop:get_associated_combinators(
		function(comb) return comb.mode == "station" end
	)
	if #combs == 0 then
		-- TODO: warning to station via api
		strace(
			WARN,
			"message",
			"Station ain't got no station comb, disabled for logistics",
			stop.entity
		)
		return false
	elseif #combs > 1 then
		strace(WARN, "message", "Station has too many station combs", stop.entity)
		return false
	end
	local comb = combs[1]
	local inputs = comb.inputs
	if not inputs then
		strace(
			WARN,
			"message",
			"Station hasn't been polled for inputs",
			stop.entity
		)
		return false
	end

	-- Set defaults
	stop.priority = 0
	stop.threshold_fluid_in = 1
	stop.threshold_fluid_out = 1
	stop.threshold_item_in = 1
	stop.threshold_item_out = 1

	-- Read configuration values
	stop.stack_thresholds =
		not not comb:read_setting(combinator_settings.use_stack_thresholds)
	local pr = comb:read_setting(combinator_settings.pr) or 0
	if pr == 0 then
		stop.is_consumer = true
		stop.is_producer = true
	elseif pr == 1 then
		stop.is_consumer = false
		stop.is_producer = true
	elseif pr == 2 then
		stop.is_consumer = true
		stop.is_producer = false
	end
	local network_signal = comb:read_setting(combinator_settings.network_signal)
	local is_each = network_signal == "signal-each"
	local networks = {}
	if network_signal and not is_each then
		networks[network_signal] = mod_settings.default_network_mask
	end
	for k, v in pairs(inputs) do
		if slib.key_is_virtual(k) then
			if k == "cybersyn2-priority" then
				stop.priority = v
			elseif k == "cybersyn2-all-items" then
				stop.threshold_item_in = v
				stop.threshold_item_out = v
			elseif k == "cybersyn2-all-fluids" then
				stop.threshold_fluid_in = v
				stop.threshold_fluid_out = v
			elseif is_each or k == network_signal then
				networks[k] = v
			end
		end
	end
	stop.networks = networks
	-- TODO: implement network operations
	stop.network_operation = 1
	stop.allow_departure_signal =
		comb:read_setting(combinator_settings.allow_departure_signal)
	stop.force_departure_signal =
		comb:read_setting(combinator_settings.force_departure_signal)
	local inact_sec = comb:read_setting(combinator_settings.inactivity_timeout)
	if inact_sec then
		stop.inactivity_timeout = inact_sec * 60 -- convert to ticks
	else
		stop.inactivity_timeout = nil
	end
	local im_setting = comb:read_setting(combinator_settings.inactivity_mode)
	if im_setting == 0 then
		stop.inactivity_mode = nil
	elseif im_setting == 1 then
		stop.inactivity_mode = "deliver"
	elseif im_setting == 2 then
		stop.inactivity_mode = "forceout"
	end
	stop.disable_cargo_condition =
		comb:read_setting(combinator_settings.disable_cargo_condition)
	stop.produce_single_item =
		comb:read_setting(combinator_settings.produce_single_item)
	stop.reserved_slots = comb:read_setting(combinator_settings.reserved_slots)
		or 0
	stop.reserved_capacity = comb:read_setting(
		combinator_settings.reserved_capacity
	) or 0
	stop.spillover = comb:read_setting(combinator_settings.spillover) or 0
	stop.ignore_secondary_thresholds =
		comb:read_setting(combinator_settings.ignore_secondary_thresholds)

	-- Inventory has already been polled at this point so nothing left to do
	-- at station comb.
	return true
end

---@param stop Cybersyn.TrainStop
function LogisticsThread:poll_train_stop(stop)
	-- Check warming-up state. Skip stops that are warming up.
	if stop.created_tick + (60 * mod_settings.warmup_time) > game.tick then
		return
	end
	-- Get station comb info
	if not self:poll_train_stop_station_comb(stop) then return end
	-- Get inventory
	stop:update_inventory(false)
	-- Get delivery thresholds
	-- Get priorities
	-- Classify inventory of stop
	return self:classify_inventory(stop)
end

---@param node Cybersyn.Node
function LogisticsThread:poll_node(node)
	if node.type == "stop" then
		return self:poll_train_stop(node --[[@as Cybersyn.TrainStop]])
	end
end

function LogisticsThread:enter_poll_nodes()
	self.providers = {}
	self.pushers = {}
	self.pullers = {}
	self.sinks = {}
	self.dumps = {}
	self.seen_cargo = {}
	self.stride =
		math.ceil(mod_settings.work_factor * cs2.PERF_NODE_POLL_WORKLOAD)
	self.index = 1
	self.iteration = 1
end

function LogisticsThread:poll_nodes()
	self:async_loop(
		self.nodes,
		self.poll_node,
		function(x) x:set_state("alloc") end
	)
end
