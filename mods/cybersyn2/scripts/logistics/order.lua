---@diagnostic disable: different-requires

local class = require("lib.core.class").class
local tlib = require("lib.core.table")
local siglib = require("lib.signal")
local thread_lib = require("lib.core.thread")
local strace = require("lib.core.strace")
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
local network_match_and = siglib.network_match_and
local network_match_or = siglib.network_match_or
local trace = strace.trace

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
		thresh_explicit = {},
		thresh_depletion = {},
		thresh_in = {},
		networks = {},
		last_fulfilled_tick = game.tick,
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
	self.thresh_depletion_fraction = stop.auto_threshold_fraction
	self.thresh_fullness_fraction = stop.train_fullness_fraction
	local depletion_fraction = self.thresh_depletion_fraction or 1
	local fullness_fraction = self.thresh_fullness_fraction or 0
	self.thresh_min_slots = (stop.allowed_min_item_slot_capacity or 0)
		* fullness_fraction
	self.thresh_min_fluid = (stop.allowed_min_fluid_capacity or 0)
		* fullness_fraction

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

	if next(self.thresh_depletion) then self.thresh_depletion = {} end
	if next(self.thresh_in) then self.thresh_in = {} end
	if next(self.networks) then self.networks = {} end
	local requests = self.requests
	local requested_fluids = self.requested_fluids
	local thresh_depletion = self.thresh_depletion
	local thresh_in = self.thresh_in

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
				local dt = compute_auto_threshold(
					requested_amt,
					depletion_fraction,
					signal_key,
					species,
					stop_amfc,
					stop_amisc
				)
				thresh_depletion[signal_key] = dt
				thresh_in[signal_key] = dt
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
	if next(self.thresh_explicit) then self.thresh_explicit = {} end
	local thresh_explicit = self.thresh_explicit
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
				thresh_in[signal_key] = direct_threshold
				thresh_explicit[signal_key] = direct_threshold
			elseif generic_item_threshold then
				local th = generic_item_threshold * key_to_stacksize(signal_key)
				thresh_in[signal_key] = th
				thresh_explicit[signal_key] = th
			end
		end
		if workload then add_workload(workload, table_size(requests)) end
	end

	-- Manual fluid thresholds
	if stop.threshold_fluid_in or stop.thresholds_in then
		local generic_fluid_threshold = stop.threshold_fluid_in
		local direct_thresholds = stop.thresholds_in or EMPTY
		for signal_key in pairs(requested_fluids) do
			local direct_threshold = direct_thresholds[signal_key]
			if direct_threshold then
				thresh_in[signal_key] = direct_threshold
				thresh_explicit[signal_key] = direct_threshold
			elseif generic_fluid_threshold then
				thresh_in[signal_key] = generic_fluid_threshold
				thresh_explicit[signal_key] = generic_fluid_threshold
			end
		end

		if workload then add_workload(workload, table_size(requested_fluids)) end
	end

	return true
end

---Determine if this requesting order is a netmatch for the given provider.
---Must always be called from requester side, as that side determines order
---matching mode.
---@param provider Cybersyn.Order
---@return boolean
function Order:matches_networks(provider)
	local rmode = self.network_matching_mode
	local rnet = self.networks
	local pnet = provider.networks
	if rmode == "and" then
		return network_match_and(rnet, pnet)
	else
		return network_match_or(rnet, pnet)
	end
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

function Order:get_provided_qty(signal_key)
	local inv_qty = self.inventory:qty(signal_key)
	local provided_qty = self.provides[signal_key] or 0
	return min(inv_qty, provided_qty)
end

---@class Cybersyn.Internal.Needs
---@field fluids SignalCounts? Explicit fluid needs.
---@field items SignalCounts? Explicit item needs.
---@field spread SignalSet? Quality spread for needs supporting it.
---@field and_spread SignalCounts? Needs for "and" mode with quality spread.
---@field or_stacks uint? If set, the number of stacks requested for "or" mode.
---@field or_mask SignalSet? If set, the set of items requested for "or" mode. Should be considered spread over qualities if spread is set.
---@field all_stacks uint? If set, the number of stacks requested for "all" mode. `spread` applies if set.
---@field thresh_explicit SignalCounts? Explicit thresholds set by user using dt comb.
---@field thresh_min_slots uint Minimum item slots dictated by fullness fraction.
---@field thresh_min_fluid uint Minimum fluid quantity dictated by fullness fraction.
---@field starvation_tick uint The last tick at which this need was fulfilled.
---@field starvation_item SignalKey? The item which has been starved the longest.

---Determine if this order is requesting any items above relevant thresholds.
---If so generate a Needs object.
---@param workload Core.Thread.Workload
---@return Cybersyn.Internal.Needs? needs
function Order:compute_needs(workload)
	if self.item_mode == "none" then return nil end

	local req_inv = self.inventory.inventory or EMPTY
	local req_inflow = self.inventory.inflow or EMPTY
	local req_starv = self.inventory.last_consumed_tick or EMPTY
	local thresh = self.thresh_in or EMPTY
	local thresh_explicit = self.thresh_explicit or EMPTY
	local spread = self.quality_spread
	local requests = self.requests
	local requested_fluids = self.requested_fluids
	local requested_stacks = self.request_stacks or 0
	local depletion_fraction = self.thresh_depletion_fraction or 1
	local thresh_min_slots = self.thresh_min_slots or 0
	local thresh_min_fluid = self.thresh_min_fluid or 0
	local starvation_tick = self.last_fulfilled_tick or 0
	local starvation_item = nil
	local game_tick = game.tick
	add_workload(workload, 2)

	-- Explicit needs
	local items = {}
	local fluids = {}
	-- Explicit fluids
	local met_thresh = false
	for key, qty in pairs(requested_fluids) do
		local has = (req_inv[key] or 0) + (req_inflow[key] or 0)
		local deficit = qty - has
		if deficit > 0 then
			if deficit >= (thresh_explicit[key] or 0) then
				fluids[key] = deficit
				local tick = req_starv[key] or 0
				if tick <= starvation_tick then
					if (game_tick - tick) >= cs2.LOGISTICS_STARVATION_TICKS then
						starvation_item = key
					end
					starvation_tick = tick
				end
			end
			if deficit >= (thresh[key] or 0) then met_thresh = true end
		end
	end
	if workload then add_workload(workload, table_size(requested_fluids)) end
	if (not met_thresh) or (not next(fluids)) then fluids = nil end

	-- Explicit items
	if self.item_mode == "and" and not spread then
		met_thresh = false
		for key, qty in pairs(requests) do
			local has = (req_inv[key] or 0) + (req_inflow[key] or 0)
			local deficit = qty - has
			if deficit > 0 then
				if deficit >= (thresh_explicit[key] or 0) then
					items[key] = deficit
					local tick = req_starv[key] or 0
					if tick <= starvation_tick then
						if (game_tick - tick) >= cs2.LOGISTICS_STARVATION_TICKS then
							starvation_item = key
						end
						starvation_tick = tick
					end
				end
				if deficit >= (thresh[key] or 0) then met_thresh = true end
			end
		end
		if workload then add_workload(workload, table_size(requests)) end
		if (not met_thresh) or (not next(items)) then items = nil end
		if items or fluids then
			---@type Cybersyn.Internal.Needs
			local res = {
				items = items,
				fluids = fluids,
				thresh_explicit = thresh_explicit,
				thresh_min_slots = thresh_min_slots,
				thresh_min_fluid = thresh_min_fluid,
				starvation_tick = starvation_tick,
				starvation_item = starvation_item,
			}
			return res
		else
			return nil
		end
	end
	if (not items) or (not next(items)) then items = nil end

	-- For exotica, we need inv net of inflow
	local inv_net = self.inventory:net(true, false, workload)

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
		met_thresh = false
		for key, qty in pairs(requests) do
			local deficit = qty - (spread_net[key] or 0)
			if deficit > 0 then
				if deficit >= (thresh_explicit[key] or 0) then
					and_spread[key] = deficit
				end
				if deficit >= (thresh[key] or 0) then met_thresh = true end
			end
		end
		if workload then add_workload(workload, table_size(requests)) end
		if (not met_thresh) or (not next(and_spread)) then and_spread = nil end

		if and_spread then
			---@type Cybersyn.Internal.Needs
			local res = {
				fluids = fluids,
				thresh_explicit = thresh_explicit,
				thresh_min_slots = thresh_min_slots,
				thresh_min_fluid = thresh_min_fluid,
				and_spread = and_spread,
				spread = spread,
				starvation_tick = starvation_tick,
				starvation_item = starvation_item,
			}
			return res
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
		local stack_threshold = requested_stacks * (depletion_fraction or 0)
		local deficit_stacks = requested_stacks - net_stacks
		if deficit_stacks >= stack_threshold and deficit_stacks > 0 then
			---@type Cybersyn.Internal.Needs
			local res = {
				fluids = fluids,
				thresh_explicit = thresh_explicit,
				thresh_min_slots = thresh_min_slots,
				thresh_min_fluid = thresh_min_fluid,
				or_stacks = deficit_stacks,
				-- This is OK; don't waste cpu generating a new mask when we can
				-- just use the input table as a mask.
				---@diagnostic disable-next-line: assign-type-mismatch
				or_mask = or_mask,
				spread = spread,
				starvation_tick = starvation_tick,
				starvation_item = starvation_item,
			}
			return res
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
		local stack_threshold = requested_stacks * (depletion_fraction or 0)
		local deficit_stacks = requested_stacks - net_stacks
		if deficit_stacks >= stack_threshold and deficit_stacks > 0 then
			---@type Cybersyn.Internal.Needs
			local res = {
				fluids = fluids,
				thresh_explicit = thresh_explicit,
				thresh_min_slots = thresh_min_slots,
				thresh_min_fluid = thresh_min_fluid,
				all_stacks = deficit_stacks,
				spread = spread,
				starvation_tick = starvation_tick,
				starvation_item = starvation_item,
			}
			return res
		end
	end

	-- Fallthrough: explicit fluids only here.
	if fluids then
		---@type Cybersyn.Internal.Needs
		local res = {
			fluids = fluids,
			thresh_explicit = thresh_explicit,
			thresh_min_slots = thresh_min_slots,
			thresh_min_fluid = thresh_min_fluid,
			starvation_tick = starvation_tick,
			starvation_item = starvation_item,
		}
		return res
	else
		return nil
	end
end

---@class (exact) Cybersyn.Internal.Satisfaction
---@field fluids SignalCounts? Satisfied fluid manifest
---@field items SignalCounts? Satisfied item manifest
---@field total_fluid uint32 Total satisfied fluid quantity
---@field total_stacks uint32 Total satisfied item stacks

---Determine if this order can provide anything that meets the given needs.
---@param workload Core.Thread.Workload
---@param needs Cybersyn.Internal.Needs
---@return Cybersyn.Internal.Satisfaction? satisfaction
function Order:satisfy_needs(workload, needs)
	trace(
		"Providing order",
		self.node_id,
		"computing satisfaction for needs",
		needs
	)
	local total_stacks = 0
	local total_fluid = 0

	local thresh_explicit = needs.thresh_explicit or EMPTY
	local thresh_min_stacks = needs.thresh_min_slots or 0
	local thresh_min_fluid = needs.thresh_min_fluid or 0

	local prov_inv = self.inventory.inventory or EMPTY
	local prov_outflow = self.inventory.outflow or EMPTY
	local prov_inflow = self.inventory.inflow or EMPTY

	-- Fluids
	local fluids = nil
	local needs_fluids = needs.fluids
	if needs_fluids then
		fluids = {}
		for key, qty in pairs(needs_fluids) do
			local available =
				min(max((prov_inv[key] or 0) - (prov_outflow[key] or 0), 0), qty)
			if available > 0 and available >= (thresh_explicit[key] or 0) then
				fluids[key] = available
				total_fluid = total_fluid + available
			end
		end
		if workload then add_workload(workload, table_size(needs_fluids)) end
		if total_fluid == 0 or total_fluid < thresh_min_fluid then
			trace(
				"Providing order",
				self.node_id,
				"fluids: no fluid match above threshold"
			)
			fluids = nil
			total_fluid = 0
		else
			trace("Providing order", self.node_id, "fluids: fluid match", fluids)
		end
	end

	-- Explicit items
	local items = nil
	local needs_items = needs.items
	if needs_items then
		items = {}
		for key, qty in pairs(needs_items) do
			local available =
				min(max((prov_inv[key] or 0) - (prov_outflow[key] or 0), 0), qty)
			if available > 0 and available >= (thresh_explicit[key] or 0) then
				items[key] = available
				local stack_size = key_to_stacksize(key) or 1
				total_stacks = total_stacks + ceil(available / stack_size)
			end
		end
		if workload then add_workload(workload, table_size(needs_items)) end

		if total_stacks >= thresh_min_stacks and next(items) then
			---@type Cybersyn.Internal.Satisfaction
			local res = {
				items = items,
				fluids = fluids,
				total_fluid = total_fluid,
				total_stacks = total_stacks,
			}
			trace(
				"Providing order",
				self.node_id,
				"explicit_items: matched items",
				res
			)
			return res
		elseif fluids then
			---@type Cybersyn.Internal.Satisfaction
			local res = {
				fluids = fluids,
				total_fluid = total_fluid,
				total_stacks = total_stacks,
			}
			trace(
				"Providing order",
				self.node_id,
				"explicit_items: no item match above threshold (fluids only)",
				res
			)
			return res
		else
			trace(
				"Providing order",
				self.node_id,
				"explicit_items: no item match above threshold"
			)
			return nil
		end
	end

	-- AND spread
	local qualities = needs.spread
	local and_spread = needs.and_spread
	if and_spread and qualities then
		-- TODO: probably unnecessary, we can just mutate and_spread
		local mutable_and_spread = tlib.assign({}, and_spread)
		if workload then add_workload(workload, table_size(and_spread)) end

		items = tlib.t_reduce(prov_inv, {}, function(itm, key, qty)
			local avail = qty - (prov_outflow[key] or 0)
			if avail > 0 then
				local sig = key_to_signal(key) --[[@as SignalID]]
				local name = sig.name --[[@as string]]
				local as_name = mutable_and_spread[name] or 0
				local wanted = min(as_name, avail)
				if wanted > 0 and qualities[sig.quality or "normal"] then
					itm[key] = wanted
					mutable_and_spread[name] = as_name - wanted
				end
			end
			return itm
		end)
		if workload then add_workload(workload, table_size(prov_inv)) end
	end

	-- OR
	local or_mask = needs.or_mask
	local or_stacks = needs.or_stacks
	if or_mask and or_stacks and (or_stacks >= thresh_min_stacks) then
		items = tlib.t_reduce(prov_inv, {}, function(itm, key, qty)
			local avail = qty - (prov_outflow[key] or 0)
			local matches_quality = true
			local mask_key = key
			if qualities then
				local sig = key_to_signal(key) --[[@as SignalID]]
				mask_key = sig.name --[[@as string]]
				matches_quality = qualities[sig.quality or "normal"]
			end
			if
				avail > 0
				and or_stacks > 0
				and matches_quality
				and or_mask[mask_key]
			then
				local stack_size = key_to_stacksize(key) or 1
				local avail_stacks = ceil(avail / stack_size)
				if avail_stacks > or_stacks then
					avail = or_stacks * stack_size
					or_stacks = 0
				elseif avail_stacks == or_stacks then
					or_stacks = 0
				else
					or_stacks = or_stacks - avail_stacks
				end
				itm[key] = avail
			end
			return itm
		end)
		if workload then add_workload(workload, table_size(prov_inv)) end
	end

	-- ALL
	local all_stacks = needs.all_stacks
	if all_stacks and all_stacks >= thresh_min_stacks then
		items = tlib.t_reduce(prov_inv, {}, function(itm, key, qty)
			local avail = qty - (prov_outflow[key] or 0)
			local matches_quality = true
			if qualities then
				local sig = key_to_signal(key) --[[@as SignalID]]
				matches_quality = qualities[sig.quality or "normal"]
			end
			if avail > 0 and all_stacks > 0 and matches_quality then
				local stack_size = key_to_stacksize(key) or 1
				local avail_stacks = ceil(avail / stack_size)
				if avail_stacks > all_stacks then
					avail = all_stacks * stack_size
					all_stacks = 0
				elseif avail_stacks == all_stacks then
					all_stacks = 0
				else
					all_stacks = all_stacks - avail_stacks
				end
				itm[key] = avail
			end
			return itm
		end)
		if workload then add_workload(workload, table_size(prov_inv)) end
	end

	if not items or (not next(items)) then
		items = nil
		total_stacks = 0
	else
		total_stacks = tlib.t_reduce(items, 0, function(stacks, key, qty)
			local stack_size = key_to_stacksize(key) or 1
			stacks = stacks + ceil(qty / stack_size)
			return stacks
		end)
		if workload then add_workload(workload, table_size(items)) end
	end

	if items then
		---@type Cybersyn.Internal.Satisfaction
		local res = {
			items = items,
			fluids = fluids,
			total_fluid = total_fluid,
			total_stacks = total_stacks,
		}
		trace(
			"Providing order",
			self.node_id,
			"exotic_items: found item match above threshold",
			res
		)
		return res
	elseif fluids then
		---@type Cybersyn.Internal.Satisfaction
		local res = {
			fluids = fluids,
			total_fluid = total_fluid,
			total_stacks = total_stacks,
		}
		trace(
			"Providing order",
			self.node_id,
			"exotic_items: no item match above threshold (fluids only)"
		)
		return res
	else
		trace(
			"Providing order",
			self.node_id,
			"exotic_items: no item match above threshold"
		)
		return nil
	end
end
