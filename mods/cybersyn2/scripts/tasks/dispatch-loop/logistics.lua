--------------------------------------------------------------------------------
-- Logistics phase
--------------------------------------------------------------------------------

local strace = require("lib.core.strace")
local slib = require("lib.signal")
local tlib = require("lib.core.table")
local thread_lib = require("lib.core.thread")
local train_lib = require("lib.trains")
local OrderStatus = require("lib.types").OrderStatus
local cmt = require("lib.core.cmt")
local era_lib = require("lib.core.math.era-counter")
local cs2 = _G.cs2

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

local pairs = _G.pairs
local next = _G.next
local table_size = _G.table_size
local add_workload = thread_lib.add_workload
local INF = math.huge
local NINF = -INF
local min = math.min
local max = math.max
local ceil = math.ceil
local dist = _G.cs2.lib.dist
local EMPTY = tlib.EMPTY_STRICT
local key_to_stacksize = slib.key_to_stacksize
local TrainDelivery = cs2.TrainDelivery
local mod_settings = _G.cs2.mod_settings
local trace = strace.trace
local warn = strace.warn
local normalize_capacity = train_lib.normalize_capacity
local tsort = table.sort
local log = math.log
local tremove = table.remove
local ipairs = ipairs

local rcall = remote.call --[[@as fun(iface:string, method:string, ...:Any):Any]]

---@class (partial) Cybersyn.LogisticsThread
---@field public req_index int
---@field public prov_index int
---@field public train_index int
---@field public requester Cybersyn.Order
---@field public reservations Cybersyn.Internal.Reservation[]
---@field public matches Cybersyn.Internal.Match[]
---@field public match Cybersyn.Internal.Match
---@field public best_train Cybersyn.Train?
---@field public best_train_index int?
---@field public best_train_score number
---@field public busy_rejections int
---@field public capacity_rejections int
---@field public allowlist_rejections int
---@field public plugin_rejections int
---@field public match_index int
---@field public match_pass int
---@field public pass_match_routed boolean
---@field public this_match_routed boolean
local LogisticsThread = cs2.LogisticsThread

---@class Cybersyn.Internal.Match
---@field public requester_node Cybersyn.Node
---@field public requester Cybersyn.Order
---@field public provider_node Cybersyn.Node
---@field public provider Cybersyn.Order
---@field public needs Cybersyn.Internal.Needs
---@field public satisfaction Cybersyn.Internal.Satisfaction
---@field public skip boolean? If `true` this match couldn't fulfill a previous need and should be skipped.

---@class Cybersyn.Internal.Reservation
---@field public item string Reserved itemkey
---@field public qty uint32 Reserved quantity
---@field public from_inv Cybersyn.Inventory Provider inv

--------------------------------------------------------------------------------
-- Matching Plugins
--------------------------------------------------------------------------------

local node_match_veto_plugins =
	prototypes.mod_data["cybersyn2"].data.node_match_veto_plugins --[[@as Core.RemoteCallbackSpec[] ]]

---@param provider Cybersyn.Node
---@param requester Cybersyn.Node
---@param workload Core.Thread.Workload
---@return boolean vetoed If `true`, the match is vetoed by a plugin.
local function query_node_match_veto_plugins(provider, requester, workload)
	for i = 1, #node_match_veto_plugins do
		local plugin = node_match_veto_plugins[i]
		local result, wkld = rcall(
			plugin[1],
			plugin[2],
			requester.id,
			provider.id,
			-- Bonus data in case of train-stop
			---@diagnostic disable-next-line: undefined-field
			requester.entity,
			-- Bonus data in case of train-stop
			---@diagnostic disable-next-line: undefined-field
			provider.entity
		) --[[@as boolean? ]]
		add_workload(workload, 1 + (wkld or 0))
		if result then return true end
	end
	return false
end

--------------------------------------------------------------------------------
-- Matching
--------------------------------------------------------------------------------

---@param from_inv Cybersyn.Inventory
function LogisticsThread:reserve(from_inv, item, qty)
	from_inv:add_single_item_outflow(item, qty)
	self.reservations[#self.reservations + 1] = {
		item = item,
		qty = qty,
		from_inv = from_inv,
	}
end

function LogisticsThread:loop_requesters()
	self.req_index = self.req_index + 1
	local index = self.req_index --[[@as int]]
	local requester = self.requesters[index]
	if not requester then
		-- This is the end of the logistics loop. All requests have been
		-- seen.
		self:set_state("loop_complete")
		return
	end
	self.requester = requester

	-- If the requester has nonempty needs, begin looping over providers,
	-- otherwise go to the next requester.
	local needs = requester:get_needs(self.workload_counter)
	if needs then
		trace(
			"Requesting order for",
			requester.node_id,
			"has needs",
			needs,
			"- iterating providers"
		)

		self.prov_index = 0
		self.matches = {}
		self:set_state("loop_providers")
	else
		trace(
			"Requester",
			requester.node_id,
			"was culled due to dispatch loop activity eliminating its needs."
		)
	end
end

function LogisticsThread:loop_providers()
	local requester = self.requester
	local requester_needs = requester.needs --[[@as Cybersyn.Internal.Needs]]
	self.prov_index = self.prov_index + 1
	local index = self.prov_index --[[@as int]]
	local provider = self.providers[index]

	add_workload(self.workload_counter, 1)

	if not provider then
		-- End of provider loop...
		self.prov_index = nil
		if next(self.matches) then
			-- Found match: Go into routing loop
			return self:set_state("sort_matches")
		else
			-- No match: Move to next req
			trace("No provider matches for requester", requester.node_id)
			requester:set_status(OrderStatus.no_provider)
			return self:set_state("loop_requesters")
		end
	end

	local provider_node = cs2.get_node(provider.node_id, true) --[[@as Cybersyn.TrainStop]]
	if not provider_node then return end

	-- Cull provider from this loop if queue is full.
	-- TODO: OPTIMIZATION: These queuechecks wastes API calls by checking node train limit twice. At the very least, factor up. Also consider caching.
	add_workload(self.workload_counter, 2)
	if provider_node:is_queue_full() or provider_node:has_max_deliveries() then
		trace(
			"Culling provider",
			provider.node_id,
			"because queue is full or has max deliveries"
		)
		tremove(self.providers, index)
		self.prov_index = self.prov_index - 1
		return
	end

	local requester_node = cs2.get_node(requester.node_id, true)
	if not requester_node then return end

	-- Check for netmatch
	if not requester:matches_networks(provider) then return end

	-- Allow plugins to reject this provider for this requester
	if
		query_node_match_veto_plugins(
			provider_node,
			requester_node,
			self.workload_counter
		)
	then
		trace(
			"Match between (",
			provider.node_id,
			requester.node_id,
			") vetoed by plugin"
		)
		return
	end

	add_workload(self.workload_counter, 2)

	-- Check for satisfying quantity
	local satisfaction =
		provider:satisfy_needs(self.workload_counter, requester_needs)

	-- Register a match
	if satisfaction then
		self.matches[#self.matches + 1] = {
			requester_node = requester_node,
			requester = requester,
			provider_node = provider_node,
			provider = provider,
			needs = requester_needs,
			satisfaction = satisfaction,
		}
	else
		-- Reserve starvation item if there is one.
		local starvation_item = requester_needs.starvation_item
		if starvation_item then
			local avail = provider:get_provided_qty(starvation_item)
			if avail > 0 then
				self:reserve(provider.inventory, starvation_item, avail)
				trace(
					"STARVATION: Requester",
					requester.node_id,
					"reserved item",
					starvation_item,
					"qty",
					avail,
					"from provider",
					provider.node_id
				)
			end
		end
	end
end

---@param match Cybersyn.Internal.Match
---@param req_stop_entity LuaEntity?
local function match_score(match, req_stop_entity)
	local prov_stop_entity = (match.provider_node --[[@as Cybersyn.TrainStop]]).entity
	local prov_busy = match.provider.busy_value
	local dx
	if
		not req_stop_entity
		or not prov_stop_entity
		or not req_stop_entity.valid
		or not prov_stop_entity.valid
	then
		dx = 20000000
	else
		dx = dist(req_stop_entity, prov_stop_entity)
	end
	local cargo = normalize_capacity(
		match.satisfaction.total_stacks,
		match.satisfaction.total_fluid
	)

	return cargo * cs2.LOGISTICS_PROVIDER_CARGO_WEIGHT
		+ dx * cs2.LOGISTICS_PROVIDER_DISTANCE_WEIGHT
		+ prov_busy * cs2.LOGISTICS_PROVIDER_BUSY_WEIGHT
end

function LogisticsThread:sort_matches()
	local requester = self.requester
	local requester_needs = requester.needs --[[@as Cybersyn.Internal.Needs]]
	local requester_node = cs2.get_node(requester.node_id, true) --[[@as Cybersyn.TrainStop]]
	local requester_stop_entity = requester_node and requester_node.entity
	if not requester then
		error("Logic error: sort_matches called with no requester set")
	end
	local starvation_item = requester_needs.starvation_item
	if requester_node:is_sharing_inventory() then
		self.requester_is_sharing_inventory = true
	else
		self.requester_is_sharing_inventory = nil
	end

	local n_matches = #self.matches

	tsort(self.matches, function(a, b)
		-- Check provider priority
		local a_prio, b_prio = a.provider.priority, b.provider.priority
		if a_prio > b_prio then return true end
		if a_prio < b_prio then return false end

		-- If starvation_item is set, prioritize who has more.
		if starvation_item then
			local a_qty = a.provider:get_provided_qty(starvation_item)
			local b_qty = b.provider:get_provided_qty(starvation_item)
			if a_qty > b_qty then return true end
			if a_qty < b_qty then return false end
		end

		-- Scoring
		local a_db = match_score(a, requester_stop_entity)
		local b_db = match_score(b, requester_stop_entity)
		return a_db > b_db
	end)
	-- This is an expensive sort.
	local n = 4 * n_matches
	add_workload(self.workload_counter, n * log(n))

	self:start_match_loop()
end

--------------------------------------------------------------------------------
-- Match loop
--------------------------------------------------------------------------------

function LogisticsThread:start_match_loop()
	self.match_index = 0
	self.match_pass = 1
	self.this_match_routed = false
	self.pass_match_routed = false
	trace(
		"Match pass beginning for requester",
		self.requester.node_id,
		"with",
		function() return #self.matches end,
		"matches"
	)
	self:set_state("loop_matches")
end

function LogisticsThread:loop_matches()
	self.match_index = self.match_index + 1
	local match = self.matches[self.match_index]
	if not match then
		if
			self.requester_is_sharing_inventory
			and mod_settings.shared_inventory_prefer_parallel
		then
			-- If this requester is sharing inventory, prefer parallelization across requesters rather than routing multiple matches in a row to the same requester.
			trace(
				"Shared Requester",
				self.requester.node_id,
				": deep iteration terminated due to parallelism preference"
			)
			return self:set_state("loop_requesters")
		end

		-- End of matches. Next pass
		self.match_pass = self.match_pass + 1
		if
			not self.pass_match_routed
			or (self.match_pass > cs2.LOGISTICS_MAX_PROVIDER_PASSES)
		then
			-- No match routed, or max passes reached: move to next requester
			return self:set_state("loop_requesters")
		end
		trace(
			"Match pass",
			self.match_pass,
			"for requester",
			self.requester.node_id
		)
		self.pass_match_routed = false
		self.match_index = 1
		match = self.matches[1]
		if not match then error("Logic error: match loop with no matches") end
	end

	-- We can early out if requester has hit its global delivery cap
	local requester = match.requester
	local requesting_stop = cs2.get_stop(requester.node_id, true)
	if (not requesting_stop) or requesting_stop:has_max_deliveries() then
		trace(
			"Requester",
			requester.node_id,
			"has reached max global deliveries; skipping to next requester"
		)
		return self:set_state("loop_requesters")
	end

	if self.match_index == 1 and self.match_pass == 1 then
		-- Very first match is always valid.
		self.match = match
		self.this_match_routed = false
		return self:start_train_loop()
	else
		-- Abort if a match was routed this pass, we are shared, and parallelization is preferred
		if
			self.requester_is_sharing_inventory
			and mod_settings.shared_inventory_prefer_parallel
			and self.pass_match_routed
		then
			trace(
				"Shared Requester",
				self.requester.node_id,
				": deep iteration terminated due to parallelism preference"
			)
			return self:set_state("loop_requesters")
		end

		-- Recompute needs of requester
		local needs = requester:get_needs(self.workload_counter)
		if not needs then
			-- Requester no longer has needs; abort match loop
			return self:set_state("loop_requesters")
		end

		-- Recompute satisfaction for this provider
		local provider = match.provider
		local satisfaction = provider:satisfy_needs(self.workload_counter, needs)
		if satisfaction then
			match.satisfaction = satisfaction
			self.match = match
			self.this_match_routed = false
			return self:start_train_loop()
		end
	end
end

--------------------------------------------------------------------------------
-- Train loop
--------------------------------------------------------------------------------

function LogisticsThread:start_train_loop()
	self.train_index = 0
	self.best_train = nil
	self.best_train_index = nil
	self.best_train_score = -INF
	self.busy_rejections = 0
	self.capacity_rejections = 0
	self.allowlist_rejections = 0
	self.plugin_rejections = 0
	self:set_state("loop_trains")
end

---Determine a numerical score for a train processing a given allocation.
---This score is used to determine the best train for the allocation.
---@param train Cybersyn.Train
---@param from Cybersyn.TrainStop
---@param to Cybersyn.TrainStop
---@param satisfaction Cybersyn.Internal.Satisfaction
---@return number
local function train_score(train, from, to, satisfaction)
	local max_moved_fluid = min(satisfaction.total_fluid, train.fluid_capacity)
	local max_moved_stacks =
		min(satisfaction.total_stacks, train.item_slot_capacity)

	-- Prefer trains that can move the most material.
	local n_train_cap =
		normalize_capacity(train.item_slot_capacity, train.fluid_capacity)
	local n_moved = normalize_capacity(max_moved_stacks, max_moved_fluid)
	-- Amongst those trains, prefer those that use the most of their capacity.
	local cap_ratio = min(n_train_cap < 1 and 0.0 or (n_moved / n_train_cap), 1.0)
	-- Amongst the best-fitting trains, penalize those that are further away
	local train_stock = train:get_stock()
	if not train_stock then return NINF end
	local stop = from.entity --[[@as LuaEntity]]
	local dx = dist(stop, train_stock)

	return (10000 * n_moved) + (1000 * cap_ratio) - dx
end

function LogisticsThread:loop_trains()
	self.train_index = self.train_index + 1
	local index = self.train_index --[[@as int]]
	local avail_train = self.avail_trains[index]
	if avail_train == false then
		-- Train was determined not available elsewhere in this loop cycle; early
		-- rejection.
		self.busy_rejections = self.busy_rejections + 1
		return
	elseif avail_train == nil then
		-- No more trains
		self.train_index = nil
		self:set_state("route_train")
		return
	end
	local train = self.trains[index]
	if not train then
		error(
			"Logic error: train index out of bounds compared with avail_trains array"
		)
	end

	-- Busy rejection
	add_workload(self.workload_counter, 6) -- `is_available` is expensive
	if not train:is_available() then
		self.avail_trains[self.train_index] = false
		self.busy_rejections = self.busy_rejections + 1
		return
	end

	-- Allowlist rejection
	local from = self.match.provider_node --[[@as Cybersyn.TrainStop]]
	local to = self.match.requester_node --[[@as Cybersyn.TrainStop]]
	add_workload(self.workload_counter, 2)
	if not (from:allows_train(train) and to:allows_train(train)) then
		self.allowlist_rejections = self.allowlist_rejections + 1
		return
	end

	if
		cs2.query_reachable_callbacks(
			train.id,
			from.id,
			to.id,
			train:get_stock(),
			train.home_surface_index,
			from.entity,
			to.entity
		)
	then
		self.plugin_rejections = self.plugin_rejections + 1
		return
	end

	-- TODO: retrieve amount moved from train_score algorithm. If it's literal
	-- zero, early-reject the train here with a capacity_rejection.
	add_workload(self.workload_counter, 4)
	local score = train_score(train, from, to, self.match.satisfaction)
	if score and score > self.best_train_score then
		self.best_train = train
		self.best_train_index = index
		self.best_train_score = score
	end
end

--------------------------------------------------------------------------------
-- Routing
--------------------------------------------------------------------------------

function LogisticsThread:route_train()
	local train = self.best_train
	local match = self.match
	local requester = match.requester
	local satisfaction = match.satisfaction
	local from = match.provider_node --[[@as Cybersyn.TrainStop]]
	local to = match.requester_node --[[@as Cybersyn.TrainStop]]
	local n_trains = #self.trains

	if not train then
		-- No train found for this allocation
		-- Log failure at nodes
		trace(
			"DELIVERY FAILED: NO TRAIN: Examined",
			n_trains,
			"trains, rejected busy:",
			self.busy_rejections,
			"capacity:",
			self.capacity_rejections,
			"allowlist:",
			self.allowlist_rejections,
			"plugin:",
			self.plugin_rejections,
			"for allocation from stop",
			from.id,
			"to stop",
			to.id,
			"with satisfaction",
			satisfaction
		)
		requester:set_status(OrderStatus.no_vehicle, {
			n = n_trains,
			busy = self.busy_rejections,
			capacity = self.capacity_rejections,
			allowlist = self.allowlist_rejections,
			plugin = self.plugin_rejections,
		})
		self:set_state("loop_matches")
		return
	end

	-- We now know this is non-nil
	local best_train_index = self.best_train_index --[[@as int]]

	-- Asynchrony requires revalidation of train
	add_workload(self.workload_counter, 1)
	if not train:is_valid() then
		-- Train is invalid, abort
		warn(
			"route_train: Train became invalid during logistics processing",
			train.id
		)
		self.avail_trains[best_train_index] = false
		requester:set_status(OrderStatus.invalidation)
		self:set_state("loop_matches")
		return
	end

	-- Asynchrony requires revalidation of nodes
	add_workload(self.workload_counter, 2)
	if (not from:is_valid()) or (not to:is_valid()) then
		-- One of the nodes is invalid, abort
		warn(
			"route_train: A node became invalid during train routing from:",
			from.id,
			"to:",
			to.id
		)
		requester:set_status(OrderStatus.invalidation)
		self:set_state("loop_matches")
		return
	end

	-- Asynchrony requires rechecking queues
	-- TODO: optimization: This wastes API calls by checking node train limit twice. At the very least, factor up. Also consider caching.
	add_workload(self.workload_counter, 2)
	if from:is_queue_full() or from:has_max_deliveries() then
		-- Source queue is full or reached max deliveries, abort
		strace.trace(
			"route_train: Source queue became full or reached max deliveries during train routing from:",
			from.id,
			"to:",
			to.id
		)
		requester:set_status(OrderStatus.provider_queue_full)
		self:set_state("loop_matches")
		return
	end

	add_workload(self.workload_counter, 1)
	if to:has_max_deliveries() then
		-- Destination queue is full, abort
		strace.trace(
			"route_train: Destination reached max deliveries during train routing from:",
			from.id,
			"to:",
			to.id
		)
		requester:set_status(OrderStatus.requester_max_deliveries)
		self:set_state("loop_matches")
		return
	end

	-- Check fuel
	add_workload(self.workload_counter, 4)
	if not train:has_fuel() then
		-- Train has no fuel, abort
		warn("route_train: Train has no fuel during logistics processing", train.id)
		self.avail_trains[best_train_index] = false
		requester:set_status(OrderStatus.invalidation)
		self:set_state("loop_matches")
		return
	end

	local n_cargo_wagons, n_fluid_wagons = train:get_wagon_counts()
	local reserved_slots = from.reserved_slots or 0
	local reserved_capacity = from.reserved_capacity or 0
	local spillover = from.spillover or 0
	local starvation_item = match.needs.starvation_item

	local manifest = {}
	local spillover_manifest = nil
	local total_item_slots = train.item_slot_capacity
	local remaining_item_slots =
		max(total_item_slots - (n_cargo_wagons * reserved_slots), 0)
	local total_fluid_capacity = train.fluid_capacity
	local remaining_fluid_capacity =
		max(total_fluid_capacity - (n_fluid_wagons * reserved_capacity), 0)
	local total_spillover = n_cargo_wagons * spillover

	-- Fluid allocation.
	-- TODO: prefer starvation_item, else prefer most fluid
	if remaining_fluid_capacity > 0 and satisfaction.fluids then
		local fluid, qty = next(satisfaction.fluids)
		if fluid and qty then
			local actual_qty = min(qty, remaining_fluid_capacity)
			if actual_qty > 0 then manifest[fluid] = actual_qty end
		end
	end

	-- Item allocations
	-- Prefer starvation_item first, then highest fulfillment qty.
	local items = satisfaction.items or EMPTY
	local item_keys, n_item_keys = tlib.keys_n(items)
	tsort(item_keys, function(a, b)
		if a == starvation_item then return true end
		if b == starvation_item then return false end
		local a_qty = items[a] or 0
		local b_qty = items[b] or 0
		return a_qty > b_qty
	end)
	add_workload(self.workload_counter, n_item_keys)

	for _, item in ipairs(item_keys) do
		local qty = items[item] or 0
		if remaining_item_slots <= 0 then break end
		local stack_size = key_to_stacksize(item) or 1
		local item_capacity = (remaining_item_slots * stack_size) - total_spillover
		local manifest_qty = min(qty, item_capacity)
		local spillover_qty = min(qty + total_spillover, item_capacity)
		local slots_needed = ceil(spillover_qty / stack_size)
		if slots_needed > remaining_item_slots then
			error("Logic error in slot calculation")
		end
		remaining_item_slots = remaining_item_slots - slots_needed
		manifest[item] = manifest_qty
		if total_spillover > 0 then
			if not spillover_manifest then spillover_manifest = {} end
			spillover_manifest[item] = spillover_qty
		end
	end
	add_workload(self.workload_counter, 2 * n_item_keys)

	-- Verify we have a manifest
	local mi1, mq1 = next(manifest)
	if (not mi1) or (mq1 < 1) then
		requester:set_status(OrderStatus.invalidation)
		self:set_state("loop_matches")
		return
	end

	-- Update various caches
	self.avail_trains[best_train_index] = false
	local tick = game.tick
	match.requester.last_fulfilled_tick = tick
	match.requester:mark_needs_as_stale()
	match.provider.busy_value = (match.provider.busy_value or 0) + 1
	local to_inv = match.requester.inventory
	for item in pairs(manifest) do
		to_inv.last_consumed_tick[item] = tick
	end
	self.pass_match_routed = true
	self.this_match_routed = true

	-- Generate the delivery
	local delivery = TrainDelivery.new(
		train,
		from,
		match.provider.inventory,
		to,
		to_inv,
		manifest,
		spillover_manifest or manifest, -- source charge
		spillover,
		reserved_slots,
		reserved_capacity
	)
	add_workload(self.workload_counter, 10)
	requester:set_status(OrderStatus.delivery)
	self.n_deliveries = self.n_deliveries + 1
	if mod_settings.debug then
		trace(
			"DELIVERY CREATED: Topology",
			self.topology_id,
			": Examined",
			n_trains,
			"trains (rejected busy:",
			self.busy_rejections,
			"capacity:",
			self.capacity_rejections,
			"allowlist:",
			self.allowlist_rejections,
			"plugin:",
			self.plugin_rejections,
			"), sent train",
			train.id,
			"with capacity(items:",
			train.item_slot_capacity,
			"fluids:",
			train.fluid_capacity,
			") from stop",
			from.id,
			"to stop",
			to.id,
			"with manifest",
			manifest
		)
		-- TODO: log delivery
	end

	self:set_state("loop_matches")
end

--------------------------------------------------------------------------------
-- Init ops
--------------------------------------------------------------------------------

function LogisticsThread:sort_requesters()
	local n = #self.requesters
	-- Requester sort
	tsort(self.requesters, function(a, b)
		local a_prio, b_prio = a.priority, b.priority
		if a_prio > b_prio then return true end
		if a_prio < b_prio then return false end
		local a_needs, b_needs = a.needs, b.needs
		-- Nothing gets in the requesters array without having `needs` set.
		---@diagnostic disable-next-line: need-check-nil
		local a_last = a_needs.starvation_tick or 0
		---@diagnostic disable-next-line: need-check-nil
		local b_last = b_needs.starvation_tick or 0
		if a_last < b_last then return true end
		if a_last > b_last then return false end
		return a.busy_value < b.busy_value
	end)
	add_workload(self.workload_counter, n * log(n))
	self:set_state("enum_trains")
end

function LogisticsThread:enum_trains()
	local trains = {}
	local avail_trains = {}
	local topology_id = self.topology_id
	local n, m = 0, 0
	for _, veh in pairs(storage.vehicles) do
		n = n + 1
		if veh.type == "train" and veh:get_topology_id() == topology_id then
			m = m + 1
			trains[m] = veh
			avail_trains[m] = true
		end
	end
	self.trains = trains
	self.avail_trains = avail_trains
	add_workload(self.workload_counter, n)
	self:set_state("loop_requesters")
end

--------------------------------------------------------------------------------
-- Loop complete
--------------------------------------------------------------------------------

function LogisticsThread:loop_complete()
	for _, res in pairs(self.reservations) do
		res.from_inv:add_single_item_outflow(res.item, -res.qty --[[@as int]])
	end
	self.reservations = nil

	local t = game.tick
	local t0 = self.last_logistics_tick
	if t0 then
		era_lib.create_or_update_era_counter(self, "logistics_era", t - t0)
	end

	era_lib.create_or_update_era_counter(
		self,
		"deliveries_era",
		self.n_deliveries
	)

	self.req_index = nil
	self:set_state("init")
	cmt.yield(self)
end

--------------------------------------------------------------------------------
-- Loop start
--------------------------------------------------------------------------------

function LogisticsThread:enter_logistics()
	if
		not self.providers
		or not self.requesters
		or ((#self.providers == 0) and (#self.requesters == 0))
	then
		self:set_state("init")
		cmt.sleep(self, 5 * 60)
		cmt.yield(self)
		return
	end
	self.last_logistics_tick = game.tick
end

function LogisticsThread:logistics()
	self.req_index = 0
	self.n_deliveries = 0
	self.reservations = {}
	self:set_state("sort_requesters")
end
