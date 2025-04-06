--------------------------------------------------------------------------------
-- poll_nodes phase
-- Step over nodes in a topology, updating state variables from combinator
-- inputs and adding their items to the logistics arrays.
--------------------------------------------------------------------------------

local stlib = require("__cybersyn2__.lib.strace")
local tlib = require("__cybersyn2__.lib.table")
local slib = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local inventory_api = _G.cs2.inventory_api
local mod_settings = _G.cs2.mod_settings
local combinator_settings = _G.cs2.combinator_settings
local logistics_thread = _G.cs2.logistics_thread

local strace = stlib.strace
local TRACE = stlib.TRACE
local WARN = stlib.WARN
local get_net_produce = inventory_api.get_net_produce
local get_net_consume = inventory_api.get_net_consume

---@param node Cybersyn.Node
---@param data Cybersyn.Internal.LogisticsThreadData
---@param item SignalKey
local function add_to_logisics_set(data, logistics_type, node, item)
	local nodes = data[logistics_type][item]
	if not nodes then
		nodes = {}
		data[logistics_type][item] = nodes
	end
	nodes[node.id] = true
end

---@param stop Cybersyn.TrainStop
---@param data Cybersyn.Internal.LogisticsThreadData
local function classify_inventory(stop, data)
	local inventory = inventory_api.get_inventory(stop.inventory_id)
	-- TODO: this is ugly, apis to get at this inventory stuff should be
	-- more centralized and less spaghetti
	strace(TRACE, "message", "classify_inventory", stop.entity, inventory)
	if not inventory then return end
	if stop.is_producer then
		for item, qty in pairs(get_net_produce(inventory)) do
			local _, out_t = stop:get_delivery_thresholds(item)
			if qty >= out_t then
				add_to_logisics_set(data, "providers", stop, item)
				data.seen_cargo[item] = true
			end
			-- TODO: push
		end
	end
	if stop.is_consumer then
		for item, qty in pairs(get_net_consume(inventory)) do
			local in_t = stop:get_delivery_thresholds(item)
			if qty <= -in_t then
				add_to_logisics_set(data, "pullers", stop, item)
				data.seen_cargo[item] = true
			end
			-- TODO: sink
		end
	end
end

---@param stop Cybersyn.TrainStop
local function poll_train_stop_station_comb(stop, data)
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
			TRACE,
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
	if not is_each then
		networks[network_signal] = 1 -- TODO: default global network mask setting
	end
	for k, v in pairs(inputs) do
		if slib.key_is_virtual(k) then
			if k == "cybersyn2-priority" then stop.priority = v end
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
	stop.networks = networks
	-- TODO: implement this
	stop.network_operation = 1

	-- Inventory has already been polled at this point so nothing left to do
	-- at station comb.
	return true
end

---@param stop Cybersyn.TrainStop
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_train_stop(stop, data)
	-- Check warming-up state. Skip stops that are warming up.
	-- TODO: this should be a mod_setting
	if stop.created_tick + 1 > game.tick then return end
	-- Get station comb info
	if not poll_train_stop_station_comb(stop, data) then return end
	-- Get delivery thresholds
	-- Get push thresholds
	-- Get sink thresholds
	-- Get priorities
	-- Classify inventory of stop
	return classify_inventory(stop, data)
end

---@param node Cybersyn.Node
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_node(node, data)
	if node.type == "stop" then
		return poll_train_stop(node --[[@as Cybersyn.TrainStop]], data)
	end
end

--------------------------------------------------------------------------------
-- Loop state lifecycle
--------------------------------------------------------------------------------

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.goto_poll_nodes(data)
	data.providers = {}
	data.pushers = {}
	data.pullers = {}
	data.sinks = {}
	data.dumps = {}
	data.seen_cargo = {}
	data.stride =
		math.ceil(mod_settings.work_factor * cs2.PERF_NODE_POLL_WORKLOAD)
	data.index = 1
	data.iteration = 1
	data.state = "poll_nodes"
end

---@param data Cybersyn.Internal.LogisticsThreadData
local function cleanup_poll_nodes(data) logistics_thread.goto_alloc(data) end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.poll_nodes(data)
	cs2.logistics_thread.stride_loop(
		data,
		data.nodes,
		poll_node,
		function(data2) cleanup_poll_nodes(data2) end
	)
end
