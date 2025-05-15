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
	-- Ignore slave stops when counting inventory qty to avoid double counting
	local count_inventory = not stop:is_sharing_slave()
	if stop.is_producer then
		inventory:foreach_producible_item(function(item, provide_qty, push_qty)
			if count_inventory and provide_qty > 0 then
				self.provided_qty[item] = (self.provided_qty[item] or 0) + provide_qty
			end
			if count_inventory and push_qty > 0 then
				self.pushed_qty[item] = (self.pushed_qty[item] or 0) + push_qty
			end
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
			if count_inventory and pull_qty > 0 then
				self.pulled_qty[item] = (self.pulled_qty[item] or 0) + pull_qty
			end
			if count_inventory and sink_qty > 0 then
				self.sunk_qty[item] = (self.sunk_qty[item] or 0) + sink_qty
			end
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
		if stop.is_dump then table.insert(self.dumps, stop) end
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
	stop.threshold_fluid_in = nil
	stop.threshold_fluid_out = nil
	stop.threshold_item_in = nil
	stop.threshold_item_out = nil

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
	stop.is_dump = comb:read_setting(combinator_settings.dump)
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
function LogisticsThread:poll_prio_combs(stop)
	stop.priorities = nil
	local combs = stop:get_associated_combinators(
		function(comb) return comb.mode == "prio" end
	)
	if #combs == 0 then return end
	local priorities = nil
	for _, comb in pairs(combs) do
		local inputs = comb.inputs
		if not inputs then return end
		for k, v in pairs(inputs) do
			if k == "cybersyn2-priority" then
				stop.priority = v
			elseif key_is_cargo(k) then
				if not priorities then priorities = {} end
				priorities[k] = v
			end
		end
	end
	stop.priorities = priorities
end

---@param stop Cybersyn.TrainStop
function LogisticsThread:poll_channels_combs(stop)
	-- Impose defaults
	stop.channels = nil
	stop.channel = nil
	-- Reread combs
	local combs = stop:get_associated_combinators(
		function(comb) return comb.mode == "channels" end
	)
	if #combs == 0 then return end
	local channels = nil
	for _, comb in pairs(combs) do
		local inputs = comb.inputs
		if not inputs then return end
		for k, v in pairs(inputs) do
			if k == "cybersyn2-all-items" then
				stop.channel = v
			elseif key_is_cargo(k) then
				if not channels then channels = {} end
				channels[k] = v
			end
		end
	end
	stop.channels = channels
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
	self:poll_dt_combs(stop)
	-- Get priorities
	self:poll_prio_combs(stop)
	-- Get channels
	self:poll_channels_combs(stop)
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
	self.provided_qty = {}
	self.pushers = {}
	self.pushed_qty = {}
	self.pullers = {}
	self.pulled_qty = {}
	self.sinks = {}
	self.sunk_qty = {}
	self.dumps = {}
	self.seen_cargo = {}
	self:begin_async_loop(
		self.nodes,
		math.ceil(cs2.PERF_NODE_POLL_WORKLOAD * mod_settings.work_factor)
	)
end

function LogisticsThread:exit_poll_nodes()
	-- Shallow copy net inventory signal counts to the topology.
	local topology = cs2.get_topology(self.topology_id)
	if not topology then return end
	topology.provided = tlib.assign({}, self.provided_qty)
	topology.pushed = tlib.assign({}, self.pushed_qty)
	topology.pulled = tlib.assign({}, self.pulled_qty)
	topology.sunk = tlib.assign({}, self.sunk_qty)
	-- Fire mass inventory update event for the topology.
	-- TODO: this should be defered to a unique state at the end of the thread
	-- so all statistics can be updated at once.
	topology:raise_inventory_updated()
end

function LogisticsThread:poll_nodes()
	self:step_async_loop(self.poll_node, function(thr) thr:set_state("cull") end)
end
