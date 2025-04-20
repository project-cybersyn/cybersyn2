local class = require("__cybersyn2__.lib.class").class
local mlib = require("__cybersyn2__.lib.math")
local slib = require("__cybersyn2__.lib.signal")
local tlib = require("__cybersyn2__.lib.table")
local stlib = require("__cybersyn2__.lib.strace")
local scheduler = require("__cybersyn2__.lib.scheduler")
local cs2 = _G.cs2
local Node = _G.cs2.Node
local Topology = _G.cs2.Topology
local Delivery = _G.cs2.Delivery
local Inventory = _G.cs2.Inventory
local TrueInventory = _G.cs2.TrueInventory
local mod_settings = _G.cs2.mod_settings
local combinator_settings = _G.cs2.combinator_settings

local strace = stlib.strace
local TRACE = stlib.TRACE
local distance_squared = mlib.pos_distsq
local pos_get = mlib.pos_get
local INF = math.huge
local tremove = table.remove
local abs = math.abs

---@class Cybersyn.TrainStop
local TrainStop = class("TrainStop", Node)
_G.cs2.TrainStop = TrainStop

---@param stop_entity LuaEntity A *valid* train stop entity.
---@return Cybersyn.TrainStop
function TrainStop.new(stop_entity)
	local stop_id = stop_entity.unit_number
	local topology = Topology.get_train_topology(stop_entity.surface_index)
	local node = Node.new("stop") --[[@as Cybersyn.TrainStop]]
	setmetatable(node, TrainStop)
	node.topology_id = topology and topology.id or nil
	node.entity = stop_entity
	node.entity_id = stop_id
	node.allowed_groups = {}
	node.allowed_layouts = {}
	node.deliveries = {}
	node.delivery_queue = {}
	cs2.raise_node_created(node)
	return node
end

---Get a train stop from storage by id.
---@param id Id
---@param skip_validation boolean?
---@return Cybersyn.TrainStop?
local function get_stop(id, skip_validation)
	local stop = Node.get(id, skip_validation)
	if stop and stop.type == "stop" then
		return stop --[[@as Cybersyn.TrainStop]]
	else
		return nil
	end
end
_G.cs2.get_stop = get_stop
TrainStop.get = get_stop

---Find the stop associated to the given rail using the rail cache.
---@param rail_entity LuaEntity A *valid* rail.
---@return Cybersyn.TrainStop? #The stop state, if found. For performance reasons, this state is not checked for validity.
function TrainStop.find_stop_from_rail(rail_entity)
	local stop_id = storage.rail_id_to_node_id[rail_entity.unit_number]
	if stop_id then
		return storage.nodes[stop_id] --[[@as Cybersyn.TrainStop?]]
	end
end

---Check if this is a valid train stop.
function TrainStop:is_valid()
	return not self.is_being_destroyed and self.entity and self.entity.valid
end

---Determine if a stop accepts the given layout ID.
---@param layout_id uint?
function TrainStop:accepts_layout(layout_id)
	if not layout_id then return false end
	return self.allowed_layouts and self.allowed_layouts[layout_id]
end

---Determine if a train is allowed at this stop.
---@param train Cybersyn.Train A *valid* train.
function TrainStop:allows_train(train)
	local layout_id = train.layout_id
	if not layout_id then return false end
	return self.allowed_layouts and self.allowed_layouts[layout_id]
	-- TODO: allowed groups
end

---Given the unit number of a train stop entity, get the stop.
---@param unit_number UnitNumber?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.TrainStop?
function TrainStop.get_stop_from_unit_number(unit_number, skip_validation)
	return Node.get(
		storage.stop_id_to_node_id[unit_number or ""],
		skip_validation
	) --[[@as Cybersyn.TrainStop?]]
end

---Given a combinator, find the nearby rail or stop that may trigger an
---association.
---TODO: other than the fact that it depends on TrainStop this code should be somewhere else...
---@param combinator_entity LuaEntity A *valid* combinator entity.
---@return LuaEntity? stop_entity The closest-to-front train stop within the combinator's association zone.
---@return LuaEntity? rail_entity The closest-to-front straight rail with a train stop within the combinator's association zone.
function _G.cs2.lib.find_associable_entities_for_combinator(combinator_entity)
	local pos = combinator_entity.position
	local pos_x, pos_y = pos_get(pos)
	local search_area = {
		{ pos_x - 1.5, pos_y - 1.5 },
		{ pos_x + 1.5, pos_y + 1.5 },
	}
	local stop = nil
	local rail = nil
	local stop_dist = INF
	local rail_dist = INF
	local entities = combinator_entity.surface.find_entities_filtered({
		area = search_area,
		name = {
			"train-stop",
			"straight-rail",
		},
	})
	for _, cur_entity in pairs(entities) do
		if cur_entity.name == "train-stop" then
			local dist = distance_squared(pos, cur_entity.position)
			if dist < stop_dist then
				stop_dist = dist
				stop = cur_entity
			end
		elseif cur_entity.type == "straight-rail" then
			-- Prefer rails with stops, then prefer rails nearer the
			-- front of the combinator.
			if TrainStop.find_stop_from_rail(cur_entity) then
				local dist = distance_squared(pos, cur_entity.position)
				if dist < rail_dist then
					rail_dist = dist
					rail = cur_entity
				end
			end
		end
	end
	return stop, rail
end

--------------------------------------------------------------------------------
-- DELIVERIES AND QUEUES
--------------------------------------------------------------------------------

---Force remove a delivery from a train stop. Generally used when delivery
---has failed.
---@param delivery_id Id
function TrainStop:force_remove_delivery(delivery_id)
	self.deliveries[delivery_id] = nil
	local queue = self.delivery_queue
	if #queue > 0 then
		self.delivery_queue = tlib.filter(
			queue,
			function(id) return id ~= delivery_id end
		)
	end
	-- Defer pop queue in case of multiple force removals, e.g. station
	-- deconstruction or inventory change.
	self:defer_pop_queue()
end

---@param delivery_id Id
function TrainStop:add_delivery(delivery_id) self.deliveries[delivery_id] = true end

function TrainStop:train_arrived(train) end

---@param train Cybersyn.Train
function TrainStop:train_departed(train)
	local delivery_id = train.delivery_id
	-- When a train makes a delivery...
	if delivery_id and self.deliveries[delivery_id] then
		-- Clear the delivery...
		local delivery = Delivery.get(delivery_id) --[[@as Cybersyn.TrainDelivery?]]
		self.deliveries[delivery_id] = nil
		-- NOTE: notify_departed adds inventory charge rebates so that hopefully
		-- update_inventory can clear them optimistcally.
		if delivery then delivery:notify_departed(self) end
		-- Then try to opportunistically re-read the station's inventory.
		self:update_inventory(true)
	end
	self:pop_queue()
end

---Determine if net inbound trains equal or exceed limit.
---@return boolean
function TrainStop:is_full()
	local limit = self.entity.trains_limit or 1000
	if limit == 0 then
		-- TODO: warn user about setting 0 limits on cs stations
	end
	return table_size(self.deliveries) >= limit
end

---Determine if the queue of this train stop exceeds the user-set global limit.
---@return boolean
function TrainStop:is_queue_full()
	local limit = mod_settings.queue_limit
	if limit == 0 then return false end
	return #self.delivery_queue >= limit
end

---If deliveries < limit, pop the queue.
function TrainStop:pop_queue()
	while not self:is_full() and #self.delivery_queue > 0 do
		local delivery_id = tremove(self.delivery_queue, 1)
		local delivery = Delivery.get(delivery_id) --[[@as Cybersyn.TrainDelivery?]]
		if delivery then delivery:notify_queue(self) end
	end
end

---Defer popping queue until next frame.
function TrainStop:defer_pop_queue()
	if self.deferred_pop_queue then return end
	self.deferred_pop_queue = scheduler.at(game.tick + 1, "pop_stop_queue", self)
end

scheduler.register_handler("pop_stop_queue", function(task)
	local stop = task.data --[[@as Cybersyn.TrainStop]]
	stop.deferred_pop_queue = nil
	if stop:is_valid() then stop:pop_queue() end
end)

function TrainStop:fail_all_deliveries(reason)
	for _, delivery_id in ipairs(self.delivery_queue) do
		local delivery = Delivery.get(delivery_id) --[[@as Cybersyn.TrainDelivery?]]
		if delivery then delivery:fail(reason) end
	end
	for delivery_id in pairs(self.deliveries) do
		local delivery = Delivery.get(delivery_id) --[[@as Cybersyn.TrainDelivery?]]
		if delivery then delivery:fail(reason) end
	end
end

---@param delivery_id Id
function TrainStop:enqueue(delivery_id)
	self.delivery_queue[#self.delivery_queue + 1] = delivery_id
end

---Gets the total number of deliveries, present and queued, for this stop.
---@return uint
function TrainStop:get_occupancy()
	return table_size(self.deliveries) + #self.delivery_queue
end

function TrainStop:get_num_deliveries() return table_size(self.deliveries) end

function TrainStop:get_queue_size() return #self.delivery_queue end

function TrainStop:get_tekbox_equation()
	local limit = math.max(self.entity.trains_limit, 1)
	return table_size(self.deliveries)
		+ (#self.delivery_queue * (limit + 1) / limit)
end

---Determine if a train parked at this stop is reversed relative to the stop.
---@param lua_train LuaTrain
---@return boolean #`true` if the train is parked backwards at this stop, `false` otherwise.
function TrainStop:is_train_reversed(lua_train)
	local back_end = lua_train.get_rail_end(defines.rail_direction.back)

	if back_end and back_end.rail then
		local back_pos = back_end.rail.position
		local stop_pos = self.entity.position
		if
			abs(back_pos.x - stop_pos.x) < 3 and abs(back_pos.y - stop_pos.y) < 3
		then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------
-- INVENTORY
--------------------------------------------------------------------------------

---Based on the combinators present at the station and its sharing state,
---update the inventory of the station as needed.
function TrainStop:update_inventory_mode()
	-- TODO: use get_combinator_with_mode
	local combs = self:get_associated_combinators(
		function(c) return c.mode == "inventory" end
	)
	if #combs == 0 then
		-- Return stop to its internal pseudoinventory
		self:set_inventory(self.created_inventory_id)
		-- Destroy created true inventory
		if self.true_inventory_id then
			local inv = Inventory.get(self.true_inventory_id)
			if inv then
				strace(
					stlib.DEBUG,
					"cs2",
					"inventory",
					"message",
					"Destroying true inventory at stop",
					self.id
				)
				inv:destroy()
			end
			self.true_inventory_id = nil
		end
	else
		-- Create true inventory if needed
		if not self.true_inventory_id then
			strace(
				stlib.DEBUG,
				"cs2",
				"inventory",
				"message",
				"Creating true inventory at stop",
				self.id
			)
			local inv = TrueInventory:new()
			self.true_inventory_id = inv.id
		end
		-- Swap stop to true inventory
		self:set_inventory(self.true_inventory_id)
	end
end

---Determine if the inventory associated with this trainstop is volatile.
---(eg. changing because a train is there being loaded/unloaded)
function TrainStop:is_inventory_volatile()
	if self.shared_inventory_master then
		local master = TrainStop.get(self.shared_inventory_master)
		if master then
			return master:is_inventory_volatile()
		else
			return not not self.entity.get_stopped_train()
		end
	elseif self.shared_inventory_slaves then
		for slave_id in pairs(self.shared_inventory_slaves) do
			local slave = TrainStop.get(slave_id)
			if slave and slave.entity.get_stopped_train() then return true end
		end
		return not not self.entity.get_stopped_train()
	else
		return not not self.entity.get_stopped_train()
	end
end

---Update this stop's inventory
---@param is_opportunistic boolean? `true` when updating inventory opportunistically (e.g. when train leaving stop), causes combinator inputs to be reread on-the-fly.
function TrainStop:update_inventory(is_opportunistic)
	if self.shared_inventory_master then
		-- Opportunistic reread at a slave station should forward to master.
		if is_opportunistic then
			local master = TrainStop.get(self.shared_inventory_master)
			if master then return master:update_inventory(is_opportunistic) end
		end
		-- Otherwise, no need to read inventory at a slave station.
		return
	end
	-- Can't read volatile inventories
	if self:is_inventory_volatile() then
		strace(
			TRACE,
			"cs2",
			"inventory",
			"stop",
			self,
			"message",
			"Inventory is volatile, not updating."
		)
		return
	end
	if self.true_inventory_id then
		local inventory = Inventory.get(self.true_inventory_id)
		if not inventory then
			strace(
				TRACE,
				"cs2",
				"inventory",
				"stop",
				self,
				"message",
				"True inventory is missing, not updating."
			)
			return
		end
		-- True inventory mode; read from Inventory combs.
		local combs = self:get_associated_combinators(
			function(c) return c.mode == "inventory" end
		)
		for _, comb in pairs(combs) do
			local inv_mode = comb:read_setting(combinator_settings.inventory_mode)
				or "inventory"
			if inv_mode == "inventory" then
				if is_opportunistic then comb:read_inputs() end
				inventory:set_base(comb.inputs or {})
			elseif inv_mode == "pull" then
				inventory:set_pulls(comb.inputs or {})
			elseif inv_mode == "push" then
				inventory:set_pushes(comb.inputs or {})
			elseif inv_mode == "sink" then
				inventory:set_sinks(comb.inputs or {})
			end
		end
	else
		-- Pseudoinventory mode; read from Station comb.
		local inventory = Inventory.get(self.created_inventory_id)
		if not inventory then
			strace(
				TRACE,
				"cs2",
				"inventory",
				"stop",
				self,
				"message",
				"Pseudoinventory is missing, not updating."
			)
			return
		end
		local combs = self:get_associated_combinators(
			function(c) return c.mode == "station" end
		)
		if #combs == 1 then
			local comb = combs[1]
			if is_opportunistic then comb:read_inputs() end
			inventory:set_base(comb.inputs or {})
		end
	end
end

function TrainStop:is_sharing_inventory()
	if self.shared_inventory_master or self.shared_inventory_slaves then
		return true
	else
		return false
	end
end

function TrainStop:is_sharing_master()
	if self.shared_inventory_slaves then
		return true
	else
		return false
	end
end

---Make this stop a shared inventory master.
function TrainStop:share_inventory()
	self.shared_inventory_slaves = {}
	cs2.raise_train_stop_shared_inventory_changed(self)
end

function TrainStop:stop_sharing_inventory()
	if self.shared_inventory_master then
		local master = cs2.get_stop(self.shared_inventory_master)
		self.shared_inventory_master = nil
		cs2.raise_train_stop_shared_inventory_changed(self)
		if master and master.shared_inventory_slaves then
			master.shared_inventory_slaves[self.id] = nil
			cs2.raise_train_stop_shared_inventory_changed(master)
		end
	end
	if self.shared_inventory_slaves then
		local slaves = self.shared_inventory_slaves --[[@as IdSet]]
		self.shared_inventory_slaves = nil
		cs2.raise_train_stop_shared_inventory_changed(self)
		for slave_id in pairs(slaves) do
			local slave = cs2.get_stop(slave_id)
			if slave then
				slave.shared_inventory_master = nil
				cs2.raise_train_stop_shared_inventory_changed(slave)
			end
		end
	end
end

---@param slave_stop Cybersyn.TrainStop
function TrainStop:share_inventory_with(slave_stop)
	if not self.shared_inventory_slaves then self.shared_inventory_slaves = {} end
	if slave_stop.shared_inventory_master ~= self.id then
		slave_stop.shared_inventory_master = self.id
		cs2.raise_train_stop_shared_inventory_changed(slave_stop)
	end
	self.shared_inventory_slaves[slave_stop.id] = true
	cs2.raise_train_stop_shared_inventory_changed(self)
end

--------------------------------------------------------------------------------
-- Stop events
--------------------------------------------------------------------------------

-- Forward train_arrived events to stops
cs2.on_train_arrived(function(train, cstrain, stop)
	if cstrain and stop then stop:train_arrived(cstrain) end
end)

-- Forward train_departed events to stops
cs2.on_train_departed(function(train, cstrain, stop)
	if cstrain and stop then stop:train_departed(cstrain) end
end)
