---@param stop Cybersyn.TrainStop
---@param combinator Cybersyn.Combinator
---@param data Cybersyn.Internal.LogisticsThreadData
local function classify_train_stop_pull_inventory(inventory, stop, combinator, data)
	if stop.can_provide then
		local provided = inventory_api.get_net_provides(inventory)
		for signal_name, count in pairs(provided) do
			data.providers[signal_name] = (data.providers[signal_name] or 0) + count
		end
	end
	if stop.can_request then
	end
end

---@param stop Cybersyn.TrainStop
---@param combinator Cybersyn.Combinator
---@param data Cybersyn.Internal.LogisticsThreadData
local function classify_train_stop_inventories(stop, combinator, data)
	local pull_inventory = inventory_api.get_inventory(stop.pull_inventory_id)
	if pull_inventory then
		classify_train_stop_pull_inventory(pull_inventory, stop, combinator, data)
	end
end

---@param signal SignalID
---@param count int
---@param stop Cybersyn.TrainStop
---@param combinator Cybersyn.Combinator
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_train_stop_configuration_signal(signal, count, stop, combinator, data)
	if signal.name == "cybersyn2-priority" then
		stop.priority = count
	elseif signal.name == "cybersyn2-item-threshold" then
		stop.threshold_item_in = math.max(0, count)
		stop.threshold_item_out = math.max(0, count)
	elseif signal.name == "cybersyn2-fluid-threshold" then
		stop.threshold_fluid_in = math.max(0, count)
		stop.threshold_fluid_out = math.max(0, count)
	elseif signal.name == "cybersyn2-item-slots" then
		stop.reserved_slots = math.max(0, count)
	elseif signal.name == "cybersyn2-fluid-slots" then
		stop.reserved_fluid_capacity = math.max(0, count)
	end
end

---@param stop Cybersyn.TrainStop
---@param combinator Cybersyn.Combinator
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_train_stop_configuration_signals(stop, combinator, data)
	local signals = logistics_thread.get_combinator_signals(data, combinator.entity)
	if signals then
		local i = 1
		while signals[i] do
			local container = signals[i]
			local signal = container.signal
			local count = container.count
			-- Consume and process configuration virtual signals
			if CONFIGURATION_VIRTUAL_SIGNAL_SET[signal.name] then
				poll_train_stop_configuration_signal(signal, count, stop, combinator, data)
				signals[i] = signals[#signals]
				signals[#signals] = nil
			else
				i = i + 1
			end
		end
	end
end

---@param stop Cybersyn.TrainStop
---@param combinator Cybersyn.Combinator
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_train_stop_networks(stop, combinator, data)
	local signals = logistics_thread.get_combinator_signals(data, combinator.entity)
	-- Get networks
	if stop.base_network == "signal-each" then
		local networks = {}
		-- Interpret all incoming non-config virtual signals as netmasks.
		if signals then
			for i = 1, #signals do
				local signal = signals[i].signal
				if signal.type == "virtual" and (not CONFIGURATION_VIRTUAL_SIGNAL_SET[signal.name]) then
					networks[signal.name] = signals[i].count
				end
			end
		end
		stop.networks = networks
	else
		stop.networks = { [stop.base_network] = -1 }
		-- Single network; vsig matching name sets mask
		if signals then
			for i = 1, #signals do
				local signal = signals[i].signal
				if signal.type == "virtual" and signal.name == stop.base_network then
					stop.networks[stop.base_network] = signals[i].count
					break
				end
			end
		end
	end
end


---@param stop Cybersyn.TrainStop
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_train_stop(stop, data)
	local combinator = combinator_api.get_combinator(stop.station_combinator_id)
	if not combinator then return end
	poll_train_stop_configuration_signals(stop, combinator, data)
	poll_train_stop_networks(stop, combinator, data)
	classify_train_stop_inventories(stop, combinator, data)
end


---@param node Cybersyn.Node
---@param data Cybersyn.Internal.LogisticsThreadData
local function poll_node(node, data)
	if stop_api.is_valid(node) then
		poll_train_stop(node --[[@as Cybersyn.TrainStop]], data)
	end
end

---@param data Cybersyn.Internal.LogisticsThreadData
local function transition_to_create_deliveries(data)
	data.nodes = nil
	data.inventories = nil
	data.stride = math.ceil(mod_settings.work_factor * PERF_NODE_POLL_WORKLOAD)
	data.index = 1
	data.state = "create_deliveries"
end

---@param data Cybersyn.Internal.LogisticsThreadData
function logistics_thread.poll_nodes(data)
	local max_index = math.min(data.index + data.stride, #data.nodes)
	for i = data.index, max_index do
		poll_node(data.nodes[i], data)
	end
	if max_index >= #data.nodes then
		transition_to_create_deliveries(data)
	else
		data.index = max_index + 1
	end
end
