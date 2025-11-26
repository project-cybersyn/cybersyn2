--------------------------------------------------------------------------------
-- Logistics phase
--------------------------------------------------------------------------------

local strace = require("lib.core.strace")
local slib = require("lib.signal")
local nmlib = require("lib.core.math.numeric")
local tlib = require("lib.core.table")
local thread_lib = require("lib.core.thread")
local train_lib = require("lib.trains")
local cs2 = _G.cs2

local pairs = _G.pairs
local next = _G.next
local table_size = _G.table_size
local add_workload = thread_lib.add_workload
local INF = math.huge
local min = math.min
local max = math.max
local ceil = math.ceil
local dist = _G.cs2.lib.dist
local EMPTY = tlib.EMPTY_STRICT
local key_to_stacksize = slib.key_to_stacksize
local TrainDelivery = _G.cs2.TrainDelivery
local mod_settings = _G.cs2.mod_settings
local trace = strace.trace
local warn = strace.warn
local normalize_capacity = train_lib.normalize_capacity

---@class Cybersyn.LogisticsThread
---@field public req_index int?
---@field public prov_index int?
---@field public train_index int?
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
local LogisticsThread = _G.cs2.LogisticsThread

---@class Cybersyn.Internal.Match
---@field public requester_node Cybersyn.Node
---@field public requester Cybersyn.Order
---@field public provider_node Cybersyn.Node
---@field public provider Cybersyn.Order
---@field public satisfaction Cybersyn.Internal.Satisfaction
---@field public skip boolean? If `true` this match couldn't fulfill a previous need and should be skipped.

---@class Cybersyn.Internal.Reservation
---@field public item string Reserved itemkey
---@field public qty uint32 Reserved quantity
---@field public from_inv Cybersyn.Inventory Provider inv

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
	if requester.needs then
		trace(
			"Requesting order for",
			requester.node_id,
			"has needs",
			requester.needs,
			"- iterating providers"
		)

		self.prov_index = 0
		self.matches = {}
		self:set_state("loop_providers")
	else
		warn(
			"Logic error: requester with no needs in logistics loop",
			requester.node_id
		)
	end
end

function LogisticsThread:loop_providers()
	self.prov_index = self.prov_index + 1
	local index = self.prov_index --[[@as int]]
	local provider = self.providers[index]
	if not provider then
		-- End of provider loop...
		self.prov_index = nil
		if #self.matches > 0 then
			-- Found match: Go into routing loop
			return self:set_state("sort_matches")
		else
			-- No match: Move to next req
			return self:set_state("loop_requesters")
		end
	end

	local requester = self.requester
	local provider_node = cs2.get_node(provider.node_id, true) --[[@as Cybersyn.TrainStop]]
	if not provider_node then return end
	local requester_node = cs2.get_node(requester.node_id, true)
	if not requester_node then return end

	-- Don't route into a full queue
	if provider_node:is_queue_full() then
		trace("Skipping provider", provider.node_id, "because queue is full")
		return
	end

	-- Check for netmatch
	if not requester:matches_networks(provider) then return end

	-- Check for satisfying quantity
	local satisfaction =
		provider:satisfy_needs(self.workload_counter, requester.needs)

	-- Register a match
	if satisfaction then
		self.matches[#self.matches + 1] = {
			requester_node = requester_node,
			requester = requester,
			provider_node = provider_node,
			provider = provider,
			satisfaction = satisfaction,
		}
	else
		local starvation_item = requester.needs.starvation_item
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
	local requester_node = cs2.get_node(requester.node_id, true) --[[@as Cybersyn.TrainStop]]
	local requester_stop_entity = requester_node and requester_node.entity
	if not requester then
		error("Logic error: sort_matches called with no requester set")
	end
	local starvation_item = requester.needs.starvation_item

	table.sort(self.matches, function(a, b)
		-- If starvation_item is set, prioritize who has more.
		if starvation_item then
			local a_qty = a.provider:get_provided_qty(starvation_item)
			local b_qty = b.provider:get_provided_qty(starvation_item)
			if a_qty > b_qty then return true end
			if a_qty < b_qty then return false end
		end

		-- Check provider priority
		local a_prio, b_prio = a.provider.priority, b.provider.priority
		if a_prio > b_prio then return true end
		if a_prio < b_prio then return false end

		-- Scoring
		local a_db = match_score(a, requester_stop_entity)
		local b_db = match_score(b, requester_stop_entity)
		return a_db > b_db
	end)
	-- This is an expensive sort.
	local n = 3 * #self.matches
	add_workload(self.workload_counter, n * math.log(n))

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
	trace("Match pass 1 for requester", self.requester.node_id)
	self:set_state("loop_matches")
end

function LogisticsThread:loop_matches()
	self.match_index = self.match_index + 1
	local match = self.matches[self.match_index]
	if not match then
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

	if self.match_index == 1 and self.match_pass == 1 then
		-- Very first match is always valid.
		self.match = match
		self.this_match_routed = false
		return self:start_train_loop()
	else
		-- Recompute needs if we routed something
		local requester = match.requester
		local needs
		if self.this_match_routed then
			-- If we routed a match, recompute full needs
			requester.needs = requester:compute_needs(self.workload_counter)
			trace(
				"Recomputed needs for requester",
				requester.node_id,
				"after successful routing",
				requester.needs
			)
		end
		needs = requester.needs

		if not needs then
			-- Requester no longer has needs; abort match loop
			return self:set_state("loop_requesters")
		end

		-- Recompute satisfaction for this provider
		local provider = match.provider
		local satisfaction =
			provider:satisfy_needs(self.workload_counter, requester.needs)
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
	local n_train_cap =
		train_lib.normalize_capacity(train.item_slot_capacity, train.fluid_capacity)
	local n_sat_size = train_lib.normalize_capacity(
		satisfaction.total_stacks,
		satisfaction.total_fluid
	)
	-- Prefer trains that can move the most material.
	local material_moved = min(n_sat_size, n_train_cap)
	-- Amongst those trains, prefer those that use the most of their capacity.
	local cap_ratio = min(n_sat_size / n_train_cap, 1.0)
	-- Amongst the best-fitting trains, penalize those that are further away
	local train_stock = train:get_stock()
	if not train_stock then return -math.huge end
	local stop = from.entity --[[@as LuaEntity]]
	local dx = dist(stop, train_stock)

	return (10000 * material_moved) + (1000 * cap_ratio) - dx
end

function LogisticsThread:loop_trains()
	self.train_index = self.train_index + 1
	local index = self.train_index --[[@as int]]
	local avail_train = self.avail_trains[index]
	if avail_train == false then
		-- Train is not available
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
	if not train:is_available() then
		self.avail_trains[self.train_index] = false
		self.busy_rejections = self.busy_rejections + 1
		return
	end

	-- Capacity rejection
	local satisfaction = self.match.satisfaction
	if
		(satisfaction.total_fluid > 0 and train.fluid_capacity == 0)
		or (satisfaction.total_stacks > 0 and train.item_slot_capacity == 0)
	then
		self.capacity_rejections = self.capacity_rejections + 1
		return
	end

	-- Allowlist rejection
	local from = self.match.provider_node --[[@as Cybersyn.TrainStop]]
	local to = self.match.requester_node --[[@as Cybersyn.TrainStop]]
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

	local score = train_score(train, from, to, self.match.satisfaction)
	if score and score > self.best_train_score then
		self.best_train = train
		self.best_train_index = index
		self.best_train_score = score
	end

	add_workload(self.workload_counter, 5)
end

--------------------------------------------------------------------------------
-- Routing
--------------------------------------------------------------------------------

function LogisticsThread:route_train()
	local train = self.best_train
	local match = self.match
	local satisfaction = match.satisfaction
	local from = match.provider_node --[[@as Cybersyn.TrainStop]]
	local to = match.requester_node --[[@as Cybersyn.TrainStop]]

	if not train then
		-- No train found for this allocation
		-- Log failure at nodes
		trace(
			"DELIVERY FAILED: NO TRAIN: Examined",
			#self.trains,
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
		self:set_state("loop_matches")
		return
	end

	-- Asynchrony requires revalidation of train
	if not train:is_valid() then
		-- Train is invalid, abort
		warn(
			"route_train: Train became invalid during logistics processing",
			train.id
		)
		self.avail_trains[self.best_train_index] = false
		self:set_state("loop_matches")
		return
	end

	-- Asynchrony requires revalidation of nodes
	if (not from:is_valid()) or (not to:is_valid()) or (from:is_queue_full()) then
		-- One of the nodes is invalid, abort
		warn(
			"route_train: A node became invalid during train routing from:",
			from.id,
			"to:",
			to.id
		)
		self:set_state("loop_matches")
		return
	end
	add_workload(self.workload_counter, 5)

	local n_cargo_wagons, n_fluid_wagons = train:get_wagon_counts()
	local reserved_slots = from.reserved_slots or 0
	local reserved_capacity = from.reserved_capacity or 0
	local spillover = from.spillover or 0

	local manifest = {}
	local spillover_manifest = nil
	local total_item_slots = train.item_slot_capacity
	local remaining_item_slots =
		max(train.item_slot_capacity - (n_cargo_wagons * reserved_slots), 0)
	local total_fluid_capacity = train.fluid_capacity
	local remaining_fluid_capacity =
		max(train.fluid_capacity - (n_fluid_wagons * reserved_capacity), 0)
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
	-- TODO: prefer starvation_item first
	local items = satisfaction.items or EMPTY
	for item, qty in pairs(items) do
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
	add_workload(self.workload_counter, 2 * table_size(items))

	-- Verify we have a manifest
	local mi1, mq1 = next(manifest)
	if (not mi1) or (mq1 < 1) then
		error("Logic error: dispatch produced an empty manifest")
	end

	-- Generate and mark delivery
	self.avail_trains[self.best_train_index] = false
	local tick = game.tick
	match.requester.last_fulfilled_tick = tick
	local to_inv = match.requester.inventory
	for item in pairs(manifest) do
		to_inv.last_consumed_tick[item] = tick
	end
	self.pass_match_routed = true
	self.this_match_routed = true
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
	if mod_settings.debug then
		trace(
			"DELIVERY CREATED: Topology",
			self.topology_id,
			": Examined",
			#self.trains,
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
-- Loop complete
--------------------------------------------------------------------------------

function LogisticsThread:loop_complete()
	for _, res in pairs(self.reservations) do
		res.from_inv:add_single_item_outflow(res.item, -res.qty)
	end
	self.reservations = nil
	self.req_index = nil
	self:set_state("init")
end

--------------------------------------------------------------------------------
-- Init ops
--------------------------------------------------------------------------------

function LogisticsThread:sort_requesters()
	local n = #self.requesters
	-- Requester sort
	table.sort(self.requesters, function(a, b)
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
	add_workload(self.workload_counter, n * math.log(n))
	self:set_state("enum_trains")
end

function LogisticsThread:enum_trains()
	local trains = {}
	local avail_trains = {}
	local topology_id = self.topology_id
	for _, veh in pairs(storage.vehicles) do
		if veh.type == "train" and veh.topology_id == topology_id then
			trains[#trains + 1] = veh
			avail_trains[#avail_trains + 1] = true
		end
	end
	self.trains = trains
	self.avail_trains = avail_trains
	add_workload(self.workload_counter, table_size(storage.vehicles))
	self:set_state("loop_requesters")
end

--------------------------------------------------------------------------------
-- Thread handlers
--------------------------------------------------------------------------------

function LogisticsThread:enter_logistics()
	-- No-work early-out cases
	if
		not self.providers
		or not self.requesters
		or (not next(self.providers))
		or (not next(self.requesters))
	then
		self:set_state("init")
		return
	end
end

function LogisticsThread:logistics()
	self.req_index = 0
	self.reservations = {}
	self:set_state("sort_requesters")
end
