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
local abs = math.abs
local add_workload = thread_lib.add_workload
local table_size = _G.table_size
local key_to_stacksize = siglib.key_to_stacksize
local INF = math.huge
local min = math.min
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
		requests = {},
		provides = {},
		thresholds_in = {},
		last_consumed_tick = {},
		networks = {},
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
	if next(self.provides) then self.provides = {} end
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
	if next(self.requests) then self.requests = {} end
	local requests = self.requests

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
				if stacked_requests and species == "item" then
					requested_amt = requested_amt * (key_to_stacksize(signal_key) or 1)
				end
				self.thresholds_in[signal_key] = compute_auto_threshold(
					requested_amt,
					self.depletion_fraction,
					signal_key,
					species,
					stop_amfc,
					stop_amisc
				)
				requests[signal_key] = requested_amt
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
		if next(self.requests) then
			self.item_mode = "or"
		else
			self.item_mode = "all"
		end
	else
		self.item_mode = "and"
	end

	-- Manual item thresholds.
	if
		(self.item_mode == "and")
		and not quality_spread
		and (stop.threshold_item_in or stop.thresholds_in)
	then
		local generic_item_threshold = stop.threshold_item_in
		local direct_thresholds = stop.thresholds_in or EMPTY
		for signal_key in pairs(self.thresholds_in) do
			if not key_is_fluid(signal_key) then
				local direct_threshold = direct_thresholds[signal_key]
				if direct_threshold then
					self.thresholds_in[signal_key] = direct_threshold
				elseif generic_item_threshold then
					self.thresholds_in[signal_key] = generic_item_threshold
						* key_to_stacksize(signal_key)
				end
			end
		end
		if workload then add_workload(workload, table_size(self.thresholds_in)) end
	end

	-- Manual fluid thresholds
	if stop.threshold_fluid_in or stop.thresholds_in then
		local generic_fluid_threshold = stop.threshold_fluid_in
		local direct_thresholds = stop.thresholds_in or EMPTY
		for signal_key in pairs(self.thresholds_in) do
			if key_is_fluid(signal_key) then
				local direct_threshold = direct_thresholds[signal_key]
				if direct_threshold then
					self.thresholds_in[signal_key] = direct_threshold
				elseif generic_fluid_threshold then
					self.thresholds_in[signal_key] = generic_fluid_threshold
				end
			end
		end
		if workload then add_workload(workload, table_size(self.thresholds_in)) end
	end

	return true
end
