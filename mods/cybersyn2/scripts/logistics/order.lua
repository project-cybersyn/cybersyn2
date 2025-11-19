local class = require("lib.core.class").class
local tlib = require("lib.core.table")
local siglib = require("lib.signal")
local thread_lib = require("lib.core.thread")
local cs2 = _G.cs2

local assign = tlib.assign
local EMPTY = tlib.EMPTY_STRICT
local mod_settings = _G.cs2.mod_settings
local pairs = _G.pairs
local next = _G.next
local classify_key = siglib.classify_key
local key_is_fluid = siglib.key_is_fluid
local key_to_signal = siglib.key_to_signal
local exploded_signal_to_key = siglib.exploded_signal_to_key
local abs = math.abs
local add_workload = thread_lib.add_workload
local table_size = _G.table_size
local key_to_stacksize = siglib.key_to_stacksize
local INF = math.huge
local min = math.min
local max = math.max
local ceil = math.ceil

---@param item SignalKey
---@param species "fluid"|"item"|nil
---@param request_qty uint
---@param frac number
---@param amfc uint?
---@param amisc uint?
---@return uint
local function compute_auto_threshold(
	request_qty,
	frac,
	item,
	species,
	amfc,
	amisc
)
	local thresh = request_qty * frac
	if species == "fluid" then
		if not amfc then
			return 2000000000 -- effectively infinite
		end
		return min(ceil(thresh), amfc)
	elseif species == "item" then
		if not amisc then
			return 2000000000 -- effectively infinite
		end
		local max_thresh = amisc * (key_to_stacksize(item) or 1)
		return min(ceil(thresh), max_thresh)
	else
		-- TODO: error log here
		return 2000000000 -- effectively infinite
	end
end

---@class Cybersyn.Order
local Order = class("Order")
_G.cs2.Order = Order

function Order:new(inventory, node_id, arity, combinator_id, combinator_input)
	local obj = {
		inventory = inventory,
		node_id = node_id,
		combinator_id = combinator_id,
		combinator_input = combinator_input,
		arity = arity, -- "primary" | "secondary"
		item_mode = "none",
		requests = {},
		requested_fluids = {},
		provides = {},
		thresholds_in = {},
		networks = {},
		last_fulfilled_tick = 0,
		starvations = {},
		priority = 0,
		busy_value = 0,
		network_matching_mode = "or",
		stacked_requests = false,
		force_away = false,
	}
	setmetatable(obj, self)
	return obj
end

---Read the value of this order from its known combinator
---@param workload Core.Thread.Workload|nil If given, the workload of this operation will be added to the counter.
---@return boolean updated `true` if the order was updated
function Order:read(workload)
	add_workload(workload, 1)

	-- Early clear provides/reqs
	if next(self.provides) then self.provides = {} end
	if next(self.requests) then self.requests = {} end
	if next(self.requested_fluids) then self.requested_fluids = {} end

	-- Sanity checks
	local stop = cs2.get_stop(self.node_id, true)
	if not stop then return false end
	local comb = cs2.get_combinator(self.combinator_id, true)
	if not comb then return false end
	local inventory = self.inventory
	if not inventory then return false end
	local inputs = self.combinator_input == "green" and comb.green_inputs
		or comb.red_inputs
	local arity = self.arity
	local stop_amfc = stop.allowed_min_fluid_capacity
	local stop_amisc = stop.allowed_min_item_slot_capacity

	-- Opts
	---@type "and" | "or"
	local network_matching_mode
	---@type string
	local network
	---@type boolean
	local stacked_requests
	---@type SignalID | nil
	local signal_force_away
	if arity == "primary" then
		network_matching_mode = comb:get_order_primary_network_matching_mode()
		network = comb:get_order_primary_network()
		stacked_requests = comb:get_order_primary_stacked_requests()
		signal_force_away = comb:get_order_primary_signal_force_away()
	else
		network_matching_mode = comb:get_order_secondary_network_matching_mode()
		network = comb:get_order_secondary_network()
		stacked_requests = comb:get_order_secondary_stacked_requests()
		signal_force_away = comb:get_order_secondary_signal_force_away()
	end
	local is_each = network == "signal-each"
	local force_away_name = signal_force_away and signal_force_away.name or nil

	-- Direct config options
	self.network_matching_mode = network_matching_mode
	self.stacked_requests = stacked_requests
	self.force_away = false
	self.busy_value = stop:get_occupancy()
	self.priority = stop.priority or 0
	self.depletion_fraction = stop.auto_threshold_fraction
	self.train_fullness_fraction = stop.train_fullness_fraction

	-- Workload for accumulating settings
	add_workload(workload, 10)

	-- Provides
	local provides = self.provides
	if comb.mode == "station" then
		-- Implement auto-provide setting.
		if
			stop.is_producer
			and not stop.is_consumer
			and not comb:get_provide_subset()
		then
			local auto_provides = self.inventory.inventory or EMPTY
			assign(provides, auto_provides)
			if workload then add_workload(workload, table_size(auto_provides)) end
		end
	end

	if next(self.thresholds_in) then self.thresholds_in = {} end
	if next(self.networks) then self.networks = {} end
	local requests = self.requests
	local requested_fluids = self.requested_fluids

	-- Signal enumeration
	---@type SignalSet?
	local quality_spread = nil
	---@type int32?
	local all_items_value
	for signal_key, count in pairs(inputs or EMPTY) do
		local genus, species = classify_key(signal_key)
		if genus == "cargo" then
			if count > 0 then
				-- Provide
				provides[signal_key] = count
			elseif count < 0 then
				-- Request
				local requested_amt = abs(count)
				if species == "item" then
					if stacked_requests then
						requested_amt = requested_amt * (key_to_stacksize(signal_key) or 1)
					end
					requests[signal_key] = requested_amt
				else
					requested_fluids[signal_key] = requested_amt
				end
				self.thresholds_in[signal_key] = compute_auto_threshold(
					requested_amt,
					self.depletion_fraction,
					signal_key,
					species,
					stop_amfc,
					stop_amisc
				)
			end
		elseif genus == "virtual" then
			if signal_key == "cybersyn2-priority" then
				self.priority = count
			elseif signal_key == "cybersyn2-all-items" then
				all_items_value = abs(count)
			elseif signal_key == "cybersyn2-all-fluids" then
				-- Ignore all fluids signal
			elseif signal_key == force_away_name then
				self.force_away = count ~= 0
			elseif is_each or signal_key == network then
				self.networks[signal_key] = count
			end
		elseif genus == "quality" then
			-- Quality spread
			quality_spread = quality_spread or {}
			quality_spread[signal_key] = true
		end
	end
	self.quality_spread = quality_spread
	if workload then add_workload(workload, 2 * table_size(inputs or EMPTY)) end

	-- TODO: if quality spread, collpase ordered items to normal quality...?

	-- Default networks
	if next(self.networks) == nil then
		if is_each then
			-- No networks specified for "each" mode: treat as empty
		elseif network then
			-- Default to the network specified on the combinator
			self.networks[network] = mod_settings.default_netmask
		elseif stop.default_networks then
			-- Default to the stop's default networks
			-- XXX: deprecated, remove for Beta
			assign(self.networks, stop.default_networks)
		end
	end
	add_workload(workload, 2)

	-- Order types
	if all_items_value then
		if next(requests) then
			self.item_mode = "or"
			self.request_stacks = all_items_value
		else
			self.item_mode = "all"
			self.request_stacks = all_items_value
		end
	elseif next(requests) or next(requested_fluids) then
		self.item_mode = "and"
		self.request_stacks = nil
	else
		self.item_mode = "none"
		self.request_stacks = nil
	end

	-- Manual item thresholds.
	if
		(self.item_mode == "and")
		and not quality_spread
		and (stop.threshold_item_in or stop.thresholds_in)
	then
		local generic_item_threshold = stop.threshold_item_in
		local direct_thresholds = stop.thresholds_in or EMPTY
		for signal_key in pairs(requests) do
			local direct_threshold = direct_thresholds[signal_key]
			if direct_threshold then
				self.thresholds_in[signal_key] = direct_threshold
			elseif generic_item_threshold then
				self.thresholds_in[signal_key] = generic_item_threshold
					* key_to_stacksize(signal_key)
			end
		end
		if workload then add_workload(workload, table_size(self.thresholds_in)) end
	end

	-- Manual fluid thresholds
	if stop.threshold_fluid_in or stop.thresholds_in then
		local generic_fluid_threshold = stop.threshold_fluid_in
		local direct_thresholds = stop.thresholds_in or EMPTY
		for signal_key in pairs(requested_fluids) do
			local direct_threshold = direct_thresholds[signal_key]
			if direct_threshold then
				self.thresholds_in[signal_key] = direct_threshold
			elseif generic_fluid_threshold then
				self.thresholds_in[signal_key] = generic_fluid_threshold
			end
		end

		if workload then add_workload(workload, table_size(requested_fluids)) end
	end

	-- Starvations
	local starvations = inventory.last_consumed_tick or EMPTY
	local oldest_starvation = self.last_fulfilled_tick or game.tick
	---@type string?
	local oldest_starvation_item = nil
	if self.item_mode == "and" then
		for key, tick in pairs(starvations) do
			if tick <= oldest_starvation and self:is_requesting(key) then
				oldest_starvation = tick
				oldest_starvation_item = key
			end
		end
		if workload then add_workload(workload, table_size(starvations)) end
	end
	self.starvation = oldest_starvation
	self.starvation_item = oldest_starvation_item

	return true
end

---Is this order requesting anything? Note that this does not consider whether
---the order is requiesting but satisfied; merely if it is requesting at all.
---@return boolean
function Order:is_requester() return (self.item_mode ~= "none") end

---Is this order providing anything? Note that this does not consider whether
---the provided resource is available in the underlying inventory; merely if
---there is an offer.
---@return boolean
function Order:is_provider() return next(self.provides) ~= nil end

---Determine if this order is requesting the given item. Note that this does
---not check whether the request is satisfied by the underlying inventory, only
---if a request is present at all.
---@param signal_key string?
---@return boolean
function Order:is_requesting(signal_key)
	if not signal_key then return false end
	local item_mode = self.item_mode
	if item_mode == "none" then return false end
	local sig = key_to_signal(signal_key)
	if not sig then return false end
	if sig.type == "fluid" then
		if self.requested_fluids[signal_key] then
			return true
		else
			return false
		end
	elseif sig.type == "item" then
		local quality_spread = self.quality_spread
		if item_mode == "all" then
			if quality_spread then
				if quality_spread[sig.quality or "normal"] then
					return true
				else
					return false
				end
			else
				return true
			end
		else
			-- and/or
			local requests = self.requests
			if quality_spread then
				if quality_spread[sig.quality or "normal"] and requests[sig.name] then
					return true
				else
					return false
				end
			else
				if requests[signal_key] then
					return true
				else
					return false
				end
			end
		end
	end
	return false
end

---@class Cybersyn.Internal.Needs
---@field fluids SignalCounts? Explicit fluid needs.
---@field items SignalCounts? Explicit item needs.
---@field spread SignalSet? Quality spread for needs supporting it.
---@field and_spread SignalCounts? Needs for "and" mode with quality spread.
---@field or_stacks uint? If set, the number of stacks requested for "or" mode.
---@field or_mask SignalSet? If set, the set of items requested for "or" mode. Should be considered spread over qualities if quality_spread is set.
---@field all_stacks uint? If set, the number of stacks requested for "all" mode. May be spread if quality_spread is set.
---@field stack_dt uint? Threshold of stacks for "or"/"all" mode.
---@field explicit_dts SignalCounts? Thresholds for explicit needs. (fluids/items)

---Determine if this order is requesting any items above relevant thresholds.
---If so generate a Needs object.
---@param workload Core.Thread.Workload
---@return Cybersyn.Internal.Needs? needs
function Order:compute_needs(workload)
	if self.item_mode == "none" then return nil end

	local inv_inv = self.inventory.inventory or EMPTY
	local inv_outflow = self.inventory.outflow or EMPTY
	local inv_inflow = self.inventory.inflow or EMPTY
	local thresh = self.thresholds_in or EMPTY
	local spread = self.quality_spread
	local requests = self.requests
	local requested_fluids = self.requested_fluids
	local requested_stacks = self.request_stacks or 0
	local fluid_thresh = thresh

	-- Explicit needs
	local items = {}
	local fluids = {}
	-- Explicit fluids
	for key, qty in pairs(requested_fluids) do
		local deficit = qty - (inv_inv[key] or 0) - (inv_inflow[key] or 0)
		local threshold = thresh[key] or 0
		if deficit >= threshold and deficit > 0 then fluids[key] = deficit end
	end
	if workload then add_workload(workload, table_size(requested_fluids)) end
	if not next(fluids) then
		fluids = nil
		---@diagnostic disable-next-line: cast-local-type
		fluid_thresh = nil
	end
	-- Explicit items
	if self.item_mode == "and" and not spread then
		for key, qty in pairs(requests) do
			local deficit = qty - (inv_inv[key] or 0) - (inv_inflow[key] or 0)
			local threshold = thresh[key] or 0
			if deficit >= threshold and deficit > 0 then items[key] = deficit end
		end
		if workload then add_workload(workload, table_size(requests)) end
		local ni = next(items)
		if ni or fluids then
			return {
				items = ni and items,
				fluids = fluids,
				explicit_dts = thresh,
			}
		else
			return nil
		end
	end
	if not next(items) then items = nil end

	-- For exotica, we need inv net of inflow
	local inv_net = self.inventory:net(true, false)

	-- AND with spread
	if self.item_mode == "and" then
		-- Unspread case was handled above.
		---@cast spread SignalSet
		local spread_net = tlib.t_reduce(
			inv_net,
			{},
			function(spread_net, key, count)
				-- These came from the inventory so no need to check for nil.
				local sig = key_to_signal(key) --[[@as SignalID]]
				local name = sig.name --[[@as string]]
				if sig and requests[name] and spread[sig.quality or "normal"] then
					spread_net[name] = (spread_net[name] or 0) + count
				end
				return spread_net
			end
		)
		if workload then add_workload(workload, table_size(inv_net)) end

		local and_spread = {}
		for key, qty in pairs(requests) do
			local deficit = qty - (spread_net[key] or 0)
			local threshold = thresh[key] or 0
			if deficit >= threshold and deficit > 0 then and_spread[key] = deficit end
		end
		if workload then add_workload(workload, table_size(requests)) end

		if next(and_spread) then
			return {
				fluids = fluids,
				explicit_dts = thresh,
				and_spread = and_spread,
				spread = spread,
			}
		end
	elseif self.item_mode == "or" then
		-- OR order
		local net_stacks, or_mask
		if spread then
			net_stacks = tlib.t_reduce(inv_net, 0, function(stacks, key, count)
				local sig = key_to_signal(key) --[[@as SignalID]]
				local name = sig.name --[[@as string]]
				if requests[name] and spread[sig.quality or "normal"] then
					local stack_size = key_to_stacksize(key) or 1
					stacks = stacks + ceil(count / stack_size)
				end
				return stacks
			end)
			if workload then add_workload(workload, table_size(inv_net)) end
			-- OR mask = cartesian product (requests x quality masks)
			or_mask = {}
			for req_key in pairs(requests) do
				for qual_key in pairs(spread) do
					local combined_key = exploded_signal_to_key(req_key, "item", qual_key)
					or_mask[combined_key] = true
				end
			end
			if workload then
				add_workload(workload, table_size(requests) * table_size(spread))
			end
		else
			net_stacks = tlib.t_reduce(inv_net, 0, function(stacks, key, count)
				if requests[key] then
					local stack_size = key_to_stacksize(key) or 1
					stacks = stacks + ceil(count / stack_size)
				end
				return stacks
			end)
			if workload then add_workload(workload, table_size(inv_net)) end
			or_mask = requests
		end
		local stack_threshold = requested_stacks * (self.depletion_fraction or 0)
		local deficit_stacks = requested_stacks - net_stacks
		if deficit_stacks >= stack_threshold and deficit_stacks > 0 then
			return {
				fluids = fluids,
				explicit_dts = fluid_thresh,
				or_stacks = deficit_stacks,
				or_mask = or_mask,
				spread = spread,
				stack_dt = stack_threshold,
			}
		end
	elseif self.item_mode == "all" then
		-- ALL order
		local net_stacks
		if spread then
			net_stacks = tlib.t_reduce(inv_net, 0, function(stacks, key, count)
				local sig = key_to_signal(key) --[[@as SignalID]]
				if spread[sig.quality or "normal"] then
					local stack_size = key_to_stacksize(key) or 1
					stacks = stacks + ceil(count / stack_size)
				end
				return stacks
			end)
			if workload then add_workload(workload, table_size(inv_net)) end
		else
			net_stacks = tlib.t_reduce(inv_net, 0, function(stacks, key, count)
				local stack_size = key_to_stacksize(key) or 1
				stacks = stacks + ceil(count / stack_size)
				return stacks
			end)
			if workload then add_workload(workload, table_size(inv_net)) end
		end
		local stack_threshold = requested_stacks * (self.depletion_fraction or 0)
		local deficit_stacks = requested_stacks - net_stacks
		if deficit_stacks >= stack_threshold and deficit_stacks > 0 then
			return {
				fluids = fluids,
				explicit_dts = fluid_thresh,
				all_stacks = deficit_stacks,
				spread = spread,
			}
		end
	end

	-- Fallthrough: explicit fluids only here.
	if fluids then
		return { fluids = fluids, explicit_dts = fluid_thresh }
	else
		return nil
	end
end

---Determine if this order can provide anything that meets the given needs.
---@param workload Core.Thread.Workload
---@param needs Cybersyn.Internal.Needs
function Order:meet_needs(workload, needs) end
