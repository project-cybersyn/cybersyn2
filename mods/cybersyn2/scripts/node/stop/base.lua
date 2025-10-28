local class = require("lib.core.class").class
local tlib = require("lib.core.table")
local stlib = require("lib.core.strace")
local scheduler = require("lib.core.scheduler")
local cs2 = _G.cs2
local Node = _G.cs2.Node
local Topology = _G.cs2.Topology
local Delivery = _G.cs2.Delivery
local mod_settings = _G.cs2.mod_settings
local combinator_settings = _G.cs2.combinator_settings

local strace = stlib.strace
local TRACE = stlib.TRACE
local INF = math.huge
local tremove = table.remove
local abs = math.abs
local empty = tlib.empty
local min = math.min

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
_G.cs2.find_stop_from_rail = TrainStop.find_stop_from_rail

---Check if this is a valid train stop.
function TrainStop:is_valid()
	return not self.is_being_destroyed and self.entity and self.entity.valid
end

---Determine if a stop accepts the given layout ID.
---@param layout_id uint?
function TrainStop:accepts_layout(layout_id)
	if not layout_id then return false end
	if self.allowed_layouts == nil then return true end
	return self.allowed_layouts[layout_id]
end

---Determine if a train is allowed at this stop.
---@param train Cybersyn.Train A *valid* train.
function TrainStop:allows_train(train)
	local layout_id = train.layout_id
	if not layout_id then return false end
	if self.allowed_layouts == nil then return true end
	return self.allowed_layouts[layout_id]
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
-- DELIVERIES AND QUEUES
--------------------------------------------------------------------------------

---Enqueue a delivery to travel to this stop. Delivery must already have been
---added via `add_delivery`.
---@param delivery_id Id
function TrainStop:enqueue(delivery_id)
	if not delivery_id or not self.deliveries[delivery_id] then
		strace(
			stlib.ERROR,
			"cs2",
			"train_stop",
			self,
			"message",
			"Enqueued nonexistent delivery.",
			delivery_id
		)
		return false
	end
	self.delivery_queue[#self.delivery_queue + 1] = delivery_id
	self:defer_process_queue()
end

---Remove a delivery from the train stop.
---@param delivery_id Id
function TrainStop:remove_delivery(delivery_id)
	local queue = self.delivery_queue
	local n_queue = #queue
	if n_queue > 0 then
		if queue[1] == delivery_id then
			-- Inline most common cases for performance.
			if n_queue == 1 then
				queue[1] = nil
			else
				tremove(queue, 1)
			end
		else
			-- General case
			self.delivery_queue = tlib.filter(
				queue,
				function(id) return id ~= delivery_id end
			)
		end
	end
	Node.remove_delivery(self, delivery_id)
	self:defer_process_queue()
end

---@param train Cybersyn.Train
function TrainStop:train_arrived(train)
	local delivery_id = train.delivery_id
	if not delivery_id or not self.deliveries[delivery_id] then return end
	local delivery = cs2.get_delivery(delivery_id) --[[@as Cybersyn.TrainDelivery?]]
	if delivery then delivery:notify_arrived(self) end
end

---@param train Cybersyn.Train
function TrainStop:train_departed(train)
	local delivery_id = train.delivery_id
	if not delivery_id or not self.deliveries[delivery_id] then return end
	-- When a train makes a delivery...
	local delivery = cs2.get_delivery(delivery_id) --[[@as Cybersyn.TrainDelivery?]]
	-- Clear the delivery. This will also defer queue processing.
	self:remove_delivery(delivery_id)
	-- TODO: consider using the event bus here.
	-- NOTE: notify_departed adds inventory charge rebates so that hopefully
	-- update_inventory can clear them optimistcally.
	if delivery then delivery:notify_departed(self) end
	-- Then try to opportunistically re-read the station's inventory.
	self:update_inventory(true)
end

---Determine if the queue of this train stop exceeds the user-set global limit.
---@return boolean
function TrainStop:is_queue_full()
	local tlimit = self.entity.trains_limit
	local limit = tlimit and mod_settings.queue_limit + tlimit
		or mod_settings.queue_limit
	if limit == 0 then return false end
	return #self.delivery_queue >= limit
end

---Signal all deliveries below the station limit that they can come to the station.
function TrainStop:process_queue()
	local queue = self.delivery_queue
	local n = min(self.entity.trains_limit or 1000, #queue)
	for i = 1, n do
		local delivery_id = queue[i]
		local delivery = cs2.get_delivery(delivery_id) --[[@as Cybersyn.TrainDelivery?]]
		if delivery then delivery:notify_queue(self) end
	end
end

---Defer processing the queue until next frame.
function TrainStop:defer_process_queue()
	if self.deferred_pop_queue then return end
	self.deferred_pop_queue = scheduler.at(game.tick + 1, "pop_stop_queue", self)
	self:defer_notify_deliveries()
end

scheduler.register_handler("pop_stop_queue", function(task)
	local stop = task.data --[[@as Cybersyn.TrainStop]]
	stop.deferred_pop_queue = nil
	if stop:is_valid() then stop:process_queue() end
end)

function TrainStop:fail_all_shared_deliveries(reason)
	if self.shared_inventory_master then
		local master = cs2.get_stop(self.shared_inventory_master)
		if master then return master:fail_all_shared_deliveries(reason) end
	end
	if self.shared_inventory_slaves then
		for slave_id in pairs(self.shared_inventory_slaves) do
			local slave = cs2.get_stop(slave_id)
			if slave then slave:fail_all_deliveries(reason) end
		end
	end
	self:fail_all_deliveries(reason)
end

---Gets the total number of deliveries, present and queued, for this stop.
---@return uint
function TrainStop:get_occupancy() return table_size(self.deliveries) end

function TrainStop:get_queue_size() return #self.delivery_queue end

function TrainStop:get_tekbox_equation()
	local limit = math.max(self.entity.trains_limit, 1)
	-- TODO: fix this; should account for queue less train limit
	return table_size(self.deliveries)
		+ (#self.delivery_queue * (limit + 1) / limit)
end

--------------------------------------------------------------------------------
-- INVENTORY
--------------------------------------------------------------------------------

---Based on the combinators present at the station and its sharing state,
---update the inventory of the station as needed.
function TrainStop:update_inventory_sharing()
	strace(
		stlib.DEBUG,
		"cs2",
		"inventory",
		"message",
		"Updating inventory sharing mode for stop",
		self
	)

	-- If slave station, set inventory to master stop
	if self.shared_inventory_master then
		local master = cs2.get_stop(self.shared_inventory_master)
		if master then
			if self:set_inventory(master.inventory_id) then
				self:fail_all_deliveries("INVENTORY_CHANGED")
			end
		end
		return
	end

	local failed_deliveries = false

	-- Reset to internal inventory if we don't have a master. No-op if already
	-- set.
	if
		self:set_inventory(self.created_inventory_id) and not failed_deliveries
	then
		self:fail_all_deliveries("INVENTORY_CHANGED")
		failed_deliveries = true
	end

	self:rebuild_inventory()
end

function TrainStop:rebuild_inventory()
	-- If shared inventory, master handles generating slave orders.
	if self.shared_inventory_master then return end
	local inventory = self:get_inventory()
	if inventory then
		---@cast inventory Cybersyn.StopInventory
		inventory:rebuild_orders()
	end
end

---Update this stop's inventory
---@param is_opportunistic boolean? If `true`, this is an opportunistic update outside the main loop, e.g. when a train leaves a stop.
function TrainStop:update_inventory(is_opportunistic)
	-- If shared inventory, forward to master when relevant.
	if self.shared_inventory_master then
		-- Opportunistic reread at a slave station should forward to master.
		if is_opportunistic then
			local master = cs2.get_stop(self.shared_inventory_master)
			if master then return master:update_inventory(true) end
		end
		-- Otherwise, no need to read inventory at a slave station.
		return
	end

	local inventory = self:get_inventory()
	-- XXX: the or condition here is just for preventing a migration
	-- crash during alpha.
	if not inventory or not inventory.update then
		strace(
			stlib.ERROR,
			"cs2",
			"inventory",
			"stop",
			self,
			"message",
			"Train stop has no inventory."
		)
		return
	end

	inventory:update(true)
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

function TrainStop:is_sharing_slave()
	if self.shared_inventory_master then
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
	if not self.shared_inventory_slaves[slave_stop.id] then
		self.shared_inventory_slaves[slave_stop.id] = true
		cs2.raise_train_stop_shared_inventory_changed(self)
	end
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

-- Shared inventory recalcs
cs2.on_train_stop_shared_inventory_changed(
	function(stop) stop:update_inventory_sharing() end
)
