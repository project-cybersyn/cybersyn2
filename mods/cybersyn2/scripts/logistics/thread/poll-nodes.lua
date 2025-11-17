--------------------------------------------------------------------------------
-- poll_nodes phase
-- Step over nodes in a topology, updating state variables from combinator
-- inputs and adding their items to the logistics arrays.
--------------------------------------------------------------------------------

local stlib = require("lib.core.strace")
local slib = require("lib.signal")
local nmlib = require("lib.core.math.numeric")
local thread_lib = require("lib.core.thread")

local cs2 = _G.cs2

local mod_settings = _G.cs2.mod_settings
local combinator_settings = _G.cs2.combinator_settings
local Topology = _G.cs2.Topology

local strace = stlib.strace
local TRACE = stlib.TRACE
local WARN = stlib.WARN
local key_is_cargo = slib.key_is_cargo
local key_is_virtual = slib.key_is_virtual
local key_is_fluid = slib.key_is_fluid
local classify_key = slib.classify_key
local key_to_stacksize = slib.key_to_stacksize
local INF = math.huge
local add_workload = thread_lib.add_workload

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

local function append_order(state, list_name, order)
	local list = state[list_name]
	if not list then
		list = {}
		state[list_name] = list
	end
	list[#list + 1] = order
end

---@param stop Cybersyn.TrainStop
function LogisticsThread:classify_inventory(stop)
	for _, view in pairs(storage.views) do
		view:enter_node(stop)
	end
	-- Inventory is classified at shared master, so skip this step for slaves.
	if stop.shared_inventory_master then
		for _, view in pairs(storage.views) do
			view:exit_node(stop)
		end
		return true
	end
	local orders = stop:get_orders()
	if not orders then
		strace(stlib.ERROR, "message", "No orders found for stop", stop)
		for _, view in pairs(storage.views) do
			view:exit_node(stop)
		end
		return false
	end
	for _, order in pairs(orders) do
		for _, view in pairs(storage.views) do
			view:enter_order(order, stop)
		end
		if stop.is_producer then
			for item in pairs(order.provides) do
				local providers = self.providers[item]
				if not providers then
					providers = {}
					self.providers[item] = providers
				end
				providers[#providers + 1] = order
			end
		end
		if stop.is_consumer then
			for item in pairs(order.requests) do
				local requesters = self.requesters[item]
				if not requesters then
					requesters = {}
					self.requesters[item] = requesters
				end
				requesters[#requesters + 1] = order
			end
			if order.request_all_items then
				append_order(self, "request_all_items", order)
			end
			if order.request_all_fluids then
				append_order(self, "request_all_fluids", order)
			end
		end
		for _, view in pairs(storage.views) do
			view:exit_order(order, stop)
		end
	end
	for _, view in pairs(storage.views) do
		view:exit_node(stop)
	end
end

---@param stop Cybersyn.TrainStop
function LogisticsThread:poll_train_stop_station_comb(stop)
	local combs = stop:get_associated_combinators(
		function(comb) return comb.mode == "station" end
	)
	local is_valid = stop:is_valid()
	if #combs == 0 and is_valid then
		cs2.create_alert(
			stop.entity,
			"no_station",
			cs2.CS2_ICON_SIGNAL_ID,
			{ "cybersyn2-alerts.no-station" }
		)
		return false
	elseif #combs > 1 and is_valid then
		cs2.create_alert(
			stop.entity,
			"too_many_station",
			cs2.CS2_ICON_SIGNAL_ID,
			{ "cybersyn2-alerts.too-many-station" }
		)
		return false
	else
		cs2.destroy_alert(stop.entity, "no_station")
		cs2.destroy_alert(stop.entity, "too_many_station")
	end
	if not is_valid then return false end
	local comb = combs[1]

	-- Read primary input wire
	local primary_wire = comb:get_primary_wire()
	comb:read_inputs()
	local inputs = comb.red_inputs
	if primary_wire == "green" then inputs = comb.green_inputs end
	if not inputs then
		strace(WARN, "message", "Couldn't read station comb inputs", stop.entity)
		return false
	end

	-- Set defaults
	stop.priority = inputs["cybersyn2-priority"] or 0
	stop.threshold_fluid_in = inputs["cybersyn2-all-fluids"]
	stop.threshold_item_in = inputs["cybersyn2-all-items"]

	-- Read configuration values
	-- Configuration signals
	stop.allow_departure_signal = comb:get_allow_departure_signal()
	stop.force_departure_signal = comb:get_force_departure_signal()
	local signal_depletion_percentage = comb:get_signal_depletion_percentage()
	local signal_fullness_percentage = comb:get_signal_fullness_percentage()
	local signal_reserved_slots = comb:get_signal_reserved_slots()
	local signal_reserved_fluid = comb:get_signal_reserved_fluid()
	local signal_spillover = comb:get_signal_spillover()

	-- Prov/req
	local pr = comb:get_pr() or 0
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

	-- Autothresholds
	stop.auto_threshold_fraction = mod_settings.default_auto_threshold_fraction
	if signal_depletion_percentage then
		local auto_threshold_percent =
			nmlib.clamp(inputs[signal_depletion_percentage.name], 0, 100, 0)
		stop.auto_threshold_fraction = auto_threshold_percent / 100
	else
		local auto_threshold_percent = comb:get_auto_threshold_percent()
		if auto_threshold_percent then
			stop.auto_threshold_fraction = auto_threshold_percent / 100
		end
	end

	stop.train_fullness_fraction = mod_settings.default_train_fullness_fraction
	if signal_fullness_percentage then
		local fullness_percent =
			nmlib.clamp(inputs[signal_fullness_percentage.name], 0, 100, 0)
		stop.train_fullness_fraction = fullness_percent / 100
	else
		local fullness_percent = comb:get_train_fullness_percent()
		if fullness_percent then
			stop.train_fullness_fraction = fullness_percent / 100
		end
	end

	if signal_reserved_slots then
		stop.reserved_slots =
			nmlib.clamp(inputs[signal_reserved_slots.name], 0, INF, 0)
	else
		stop.reserved_slots = comb:get_reserved_slots() or 0
	end

	if signal_reserved_fluid then
		stop.reserved_capacity =
			nmlib.clamp(inputs[signal_reserved_fluid.name], 0, INF, 0)
	else
		stop.reserved_capacity = comb:get_reserved_capacity() or 0
	end

	if signal_spillover then
		stop.spillover = nmlib.clamp(inputs[signal_spillover.name], 0, INF, 0)
	else
		stop.spillover = comb:get_spillover() or 0
	end

	-- Default networks (deprecated/hidden, should now be set at order level)
	local default_networks = {}
	local network_signal = comb:get_network_signal()
	if network_signal then default_networks[network_signal] = -1 end
	stop.default_networks = default_networks

	-- Depature controls
	local inact_sec = comb:get_inactivity_timeout()
	if inact_sec then
		stop.inactivity_timeout = inact_sec * 60 -- convert to ticks
	else
		stop.inactivity_timeout = nil
	end
	local im_setting = comb:get_inactivity_mode()
	if im_setting == 0 then
		stop.inactivity_mode = nil
	elseif im_setting == 1 then
		stop.inactivity_mode = "deliver"
	elseif im_setting == 2 then
		stop.inactivity_mode = "forceout"
	end
	stop.disable_cargo_condition = comb:get_disable_cargo_condition()

	-- Outbound handling
	stop.produce_single_item = comb:get_produce_single_item()

	return true
end

---@param workload Core.Thread.Workload?
---@param stop Cybersyn.TrainStop
function LogisticsThread:poll_dt_combs(workload, stop)
	local thresholds_in = nil
	for _, comb in cs2.iterate_combinators(stop) do
		if comb.mode ~= "dt" then goto continue end
		comb:read_inputs()
		add_workload(workload, 5)
		local inputs = comb.inputs
		if not inputs then goto continue end
		local stacked = not comb:get_dt_unstacked()
		for k, v in pairs(inputs) do
			add_workload(workload, 1)
			if k == "cybersyn2-all-items" then
				stop.threshold_item_in = v
			elseif k == "cybersyn2-all-fluids" then
				stop.threshold_fluid_in = v
			else
				local genus, species = classify_key(k)
				if genus == "cargo" then
					if species == "fluid" then
						if not thresholds_in then thresholds_in = {} end
						thresholds_in[k] = v
					elseif species == "item" then
						local stack_size = 1
						if stacked then stack_size = key_to_stacksize(k) or 1 end
						if not thresholds_in then thresholds_in = {} end
						thresholds_in[k] = v * stack_size
					end
				end
			end
		end
		::continue::
	end
	stop.thresholds_in = thresholds_in
end

---@param stop Cybersyn.TrainStop
function LogisticsThread:poll_train_stop(stop)
	-- Check warming-up state. Skip stops that are warming up.
	if stop.created_tick + (60 * mod_settings.warmup_time) > game.tick then
		return
	end
	-- Get station comb info
	if not self:poll_train_stop_station_comb(stop) then return end
	-- Get delivery thresholds
	self:poll_dt_combs(nil, stop)
	-- Get inventory
	stop:update_inventory(false)
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
	self.requesters = {}
	self.request_all_items = {}
	self.request_all_fluids = {}
	self:begin_async_loop(
		self.nodes,
		math.ceil(cs2.PERF_POLL_NODES_WORKLOAD * mod_settings.work_factor)
	)
	local topology = cs2.get_topology(self.topology_id)
	if topology then
		for _, view in pairs(storage.views) do
			view:enter_nodes(topology)
		end
	end
end

function LogisticsThread:exit_poll_nodes()
	local topology = cs2.get_topology(self.topology_id)
	if topology then
		for _, view in pairs(storage.views) do
			view:exit_nodes(topology)
		end
	end
end

function LogisticsThread:poll_nodes()
	self:step_async_loop(self.poll_node, function(thr) thr:set_state("init") end)
end
