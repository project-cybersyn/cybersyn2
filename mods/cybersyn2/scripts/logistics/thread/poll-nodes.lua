--------------------------------------------------------------------------------
-- poll_nodes phase
-- Step over nodes in a topology, updating state variables from combinator
-- inputs and adding their items to the logistics arrays.
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local tlib = require("__cybersyn2__.lib.table")
local slib = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local node_api = _G.cs2.node_api
local stop_api = _G.cs2.stop_api
local inventory_api = _G.cs2.inventory_api
local mod_settings = _G.cs2.mod_settings
local combinator_settings = _G.cs2.combinator_settings
local logistics_thread = _G.cs2.logistics_thread

local get_net_produce = inventory_api.get_net_produce
local get_net_consume = inventory_api.get_net_consume
local get_inbound_threshold = stop_api.get_inbound_threshold
local get_outbound_threshold = stop_api.get_outbound_threshold

local function add_node(data, class, key, node)
	local nodes = data[class][key]
	if not nodes then
		nodes = {}
		data[class][key] = nodes
	end
	nodes[#node + 1] = node
end

---@param stop Cybersyn.TrainStop
---@param data Cybersyn.Internal.LogisticsThreadData
local function classify_inventory(stop, data)
	local inventory = inventory_api.get_inventory(stop.inventory_id)
	log.trace("classify_inventory", stop.entity, inventory)
	if not inventory then return end
	if stop.is_producer then
		for k, v in get_net_produce(inventory) do
			local out_t = get_outbound_threshold(stop, k)
			if v >= out_t then add_node(data, "providers", k, stop) end
			-- TODO: push
		end
	end
	if stop.is_consumer then
		for k, v in get_net_consume(inventory) do
			local in_t = get_inbound_threshold(stop, k)
			if v <= -in_t then add_node(data, "pullers", k, stop) end
			-- TODO: sink
		end
	end
end

---@param stop Cybersyn.TrainStop
local function poll_train_stop_station_comb(stop, data)
	local combs = node_api.get_associated_combinators(
		stop,
		function(comb) return comb.mode == "station" end
	)
	if #combs == 0 then
		-- TODO: warning to station via api
		log.warn(
			"Station ain't got no station comb, disabled for logistics",
			stop.entity
		)
		return false
	elseif #combs > 1 then
		log.warn("Station has too many station combs", stop.entity)
		return false
	end
	local comb = combs[1]
	local inputs = comb.inputs
	if not inputs then
		log.info("Station hasn't been polled for inputs", stop.entity)
		return false
	end

	-- Set defaults
	stop.priority = 0
	stop.threshold_fluid_in = 1
	stop.threshold_fluid_out = 1
	stop.threshold_item_in = 1
	stop.threshold_item_out = 1

	-- Read configuration vsignals
	local network_signal =
		combinator_api.read_setting(comb, combinator_settings.network_signal)
	local is_each = network_signal == "signal-each"
	local networks = {}
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
		math.ceil(mod_settings.work_factor * cs2.PERF_COMB_POLL_WORKLOAD)
	data.index = 1
	data.iteration = 1
	data.state = "poll_nodes"
end

---@param data Cybersyn.Internal.LogisticsThreadData
local function cleanup_poll_nodes(data)
	logistics_thread.set_state(data, "next_t")
end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.poll_nodes(data)
	cs2.logistics_thread.stride_loop(
		data,
		data.nodes,
		poll_node,
		function(data2) cleanup_poll_nodes(data2) end
	)
end
