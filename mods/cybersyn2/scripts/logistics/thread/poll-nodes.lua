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
local Topology = _G.cs2.Topology

local strace = stlib.strace
local TRACE = stlib.TRACE
local WARN = stlib.WARN
local key_is_cargo = slib.key_is_cargo
local key_is_virtual = slib.key_is_virtual
local INF = math.huge

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
	-- Inventory is classified at shared master, so skip this step for slaves.
	if stop.shared_inventory_master then return true end
	local orders = stop:get_orders()
	if not orders then
		strace(stlib.ERROR, "message", "No orders found for stop", stop)
		return false
	end
	for _, order in pairs(orders) do
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
	local primary_wire = comb:read_setting(combinator_settings.primary_wire)
	comb:read_inputs()
	local inputs = comb.red_inputs
	if primary_wire == "green" then inputs = comb.green_inputs end
	if not inputs then
		strace(WARN, "message", "Couldn't read station comb inputs", stop.entity)
		return false
	end

	-- Set defaults
	stop.priority = 0
	stop.threshold_fluid_in = nil
	stop.threshold_fluid_out = nil
	stop.threshold_item_in = nil
	stop.threshold_item_out = nil

	-- Compute max autothresholds
	stop.threshold_auto_fluid_max = nil
	stop.threshold_auto_item_max = nil
	for layout_id in pairs(stop.allowed_layouts) do
		local layout = storage.train_layouts[layout_id]
		if layout then
			local fluid_cap = layout.min_fluid_capacity
			local item_cap = layout.min_item_slot_capacity
			if fluid_cap and fluid_cap < (stop.threshold_auto_fluid_max or INF) then
				stop.threshold_auto_fluid_max = fluid_cap
			end
			if item_cap and item_cap < (stop.threshold_auto_item_max or INF) then
				stop.threshold_auto_item_max = item_cap
			end
		end
	end

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
	local default_networks = {}
	for k, v in pairs(inputs) do
		if k == "cybersyn2-priority" then
			stop.priority = v
		elseif k == "cybersyn2-all-items" then
			stop.threshold_item_in = v
			stop.threshold_item_out = v
		elseif k == "cybersyn2-all-fluids" then
			stop.threshold_fluid_in = v
			stop.threshold_fluid_out = v
		elseif key_is_virtual(k) then
			default_networks[k] = true
		end
	end
	if not next(default_networks) then
		local network_signal = comb:read_setting(combinator_settings.network_signal)
		if network_signal then default_networks = { [network_signal] = true } end
	end
	stop.default_networks = default_networks
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
function LogisticsThread:poll_dt_combs(stop)
	stop.thresholds_in = nil
	stop.thresholds_out = nil
	local combs = stop:get_associated_combinators(
		function(comb) return comb.mode == "dt" end
	)
	if #combs == 0 then return end
	local thresholds_in = nil
	local thresholds_out = nil
	for _, comb in pairs(combs) do
		comb:read_inputs()
		local inputs = comb.inputs
		if not inputs then return end
		local is_in = comb:read_setting(combinator_settings.dt_inbound)
		local is_out = comb:read_setting(combinator_settings.dt_outbound)
		for k, v in pairs(inputs) do
			if k == "cybersyn2-all-items" then
				if is_in then stop.threshold_item_in = v end
				if is_out then stop.threshold_item_out = v end
			elseif k == "cybersyn2-all-fluids" then
				if is_in then stop.threshold_fluid_in = v end
				if is_out then stop.threshold_fluid_out = v end
			elseif key_is_cargo(k) then
				if is_in then
					if not thresholds_in then thresholds_in = {} end
					thresholds_in[k] = v
				end
				if is_out then
					if not thresholds_out then thresholds_out = {} end
					thresholds_out[k] = v
				end
			end
		end
	end
	stop.thresholds_in = thresholds_in
	stop.thresholds_out = thresholds_out
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
	self:poll_dt_combs(stop)
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
		math.ceil(cs2.PERF_NODE_POLL_WORKLOAD * mod_settings.work_factor)
	)
end

function LogisticsThread:exit_poll_nodes()
	-- Shallow copy net inventory signal counts to the topology.
	local topology = cs2.get_topology(self.topology_id)
	if not topology then return end
	-- TODO: net inventory stats

	-- Fire mass inventory update event for the topology.
	-- TODO: this should be defered to a unique state at the end of the thread
	-- so all statistics can be updated at once.
	topology:raise_inventory_updated()
end

function LogisticsThread:poll_nodes()
	self:step_async_loop(self.poll_node, function(thr) thr:set_state("alloc") end)
end
