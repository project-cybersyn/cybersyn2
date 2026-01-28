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
local pairs = _G.pairs
local clamp = nmlib.clamp
local STATUS_WORKING = defines.entity_status.working

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

--------------------------------------------------------------------------------
-- Classify
--------------------------------------------------------------------------------

function LogisticsThread:enter_poll_train_stop_classify_inventory()
	-- Only run on first entry
	if not self.order_index then
		local stop = self.node --[[@as Cybersyn.TrainStop]]
		for _, view in pairs(storage.views) do
			view:enter_node(self.workload_counter, stop)
		end
		if stop.shared_inventory_master then
			-- Shared inventory slave; allow the master to classify inventory
			return self:set_state("poll_nodes")
		end

		self.orders = stop:get_orders()
		if not self.orders then return self:set_state("poll_nodes") end

		self.order_index = 0
	end
end

function LogisticsThread:exit_poll_train_stop_classify_inventory()
	self.order_index = nil
	self.orders = nil
	local stop = self.node --[[@as Cybersyn.TrainStop]]
	for _, view in pairs(storage.views) do
		view:exit_node(self.workload_counter, stop)
	end
end

function LogisticsThread:poll_train_stop_classify_inventory()
	self.order_index = self.order_index + 1
	local index = self.order_index --[[@as int]]
	local order = self.orders[index]
	if not order then return self:set_state("poll_nodes") end

	local stop = self.node --[[@as Cybersyn.TrainStop]]
	if not stop:is_valid() then self:set_state("poll_nodes") end

	-- Shared inventory: order may be for a different stop.
	local order_stop = stop --[[@as Cybersyn.TrainStop?]]
	if order.node_id ~= stop.id then order_stop = cs2.get_stop(order.node_id) end
	local providers = self.providers
	local requesters = self.requesters

	add_workload(self.workload_counter, 1)

	for _, view in pairs(storage.views) do
		view:enter_order(self.workload_counter, order, stop)
	end
	if order_stop and order_stop.is_producer and order:is_provider() then
		providers[#providers + 1] = order
	end
	if order_stop and order_stop.is_consumer and order:is_requester() then
		if not order_stop:has_max_deliveries() then
			order.needs = order:compute_needs(self.workload_counter)
			if order.needs then requesters[#requesters + 1] = order end
		else
			stlib.trace(
				"Culling requesting order on stop with max deliveries",
				order_stop.id
			)
		end
	end
	for _, view in pairs(storage.views) do
		view:exit_order(self.workload_counter, order, stop)
	end
end

--------------------------------------------------------------------------------
-- Poll
--------------------------------------------------------------------------------

---@param workload Core.Thread.Workload
---@param stop Cybersyn.TrainStop
function LogisticsThread:poll_train_stop_station_comb(workload, stop)
	add_workload(workload, 1)
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
	add_workload(workload, 2)

	-- Verify status of station comb entity
	local comb_entity = comb.real_entity
	if
		not comb_entity
		or not comb_entity.valid
		or (comb_entity.status ~= STATUS_WORKING)
	then
		return false
	end

	-- Read primary input wire
	local primary_wire = comb:get_primary_wire()
	comb:read_inputs(nil, workload)
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
			clamp(inputs[signal_depletion_percentage.name], 0, 100, 0)
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
			clamp(inputs[signal_fullness_percentage.name], 0, 100, 0)
		stop.train_fullness_fraction = fullness_percent / 100
	else
		local fullness_percent = comb:get_train_fullness_percent()
		if fullness_percent then
			stop.train_fullness_fraction = fullness_percent / 100
		end
	end

	if signal_reserved_slots then
		stop.reserved_slots = clamp(inputs[signal_reserved_slots.name], 0, INF, 0)
	else
		stop.reserved_slots = comb:get_reserved_slots() or 0
	end

	if signal_reserved_fluid then
		stop.reserved_capacity =
			clamp(inputs[signal_reserved_fluid.name], 0, INF, 0)
	else
		stop.reserved_capacity = comb:get_reserved_capacity() or 0
	end

	if signal_spillover then
		stop.spillover = clamp(inputs[signal_spillover.name], 0, INF, 0)
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
	stop.fullness_when_providing = comb:get_fullness_when_providing()

	add_workload(workload, 3)

	return true
end

---@param workload Core.Thread.Workload?
---@param stop Cybersyn.TrainStop
function LogisticsThread:poll_dt_combs(workload, stop)
	local thresholds_in = nil
	for _, comb in cs2.iterate_combinators(stop) do
		if comb.mode ~= "dt" then goto continue end
		comb:read_inputs(nil, workload)
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

function LogisticsThread:poll_train_stop_update_inventory()
	local stop = self.node --[[@as Cybersyn.TrainStop]]
	stop:update_inventory(self.workload_counter, false)
	self:set_state("poll_train_stop_classify_inventory")
end

function LogisticsThread:poll_train_stop()
	local stop = self.node --[[@as Cybersyn.TrainStop]]
	local workload = self.workload_counter
	add_workload(workload, 1)
	-- Check warming-up state. Skip stops that are warming up.
	if stop.created_tick + (60 * mod_settings.warmup_time) > game.tick then
		return self:set_state("poll_nodes")
	end
	-- Get station comb info
	if not self:poll_train_stop_station_comb(workload, stop) then
		return self:set_state("poll_nodes")
	end
	-- Get delivery thresholds
	self:poll_dt_combs(workload, stop)
	self:set_state("poll_train_stop_update_inventory")
end

--------------------------------------------------------------------------------
-- State handlers
--------------------------------------------------------------------------------

function LogisticsThread:enter_poll_nodes()
	-- Only run on first entry
	if not self.node_index then
		self.providers = {}
		self.requesters = {}
		self.node_index = 0

		local topology = cs2.get_topology(self.topology_id)
		if topology then
			for _, view in pairs(storage.views) do
				view:enter_nodes(self.workload_counter, topology)
			end
		end
	end
end

function LogisticsThread:poll_nodes()
	self.node_index = self.node_index + 1
	local index = self.node_index --[[@as int]]
	local node = self.nodes[index]
	self.node = node
	if not node then
		self.node_index = nil
		local topology = cs2.get_topology(self.topology_id)
		if topology then
			for _, view in pairs(storage.views) do
				view:exit_nodes(self.workload_counter, topology)
			end
		end
		return self:set_state("logistics")
	end

	if node.type == "stop" then self:set_state("poll_train_stop") end
end
