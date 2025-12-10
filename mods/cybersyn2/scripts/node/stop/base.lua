local class = require("lib.core.class").class
local tlib = require("lib.core.table")
local stlib = require("lib.core.strace")
local scheduler = require("lib.core.scheduler")
local events = require("lib.core.event")

local cs2 = _G.cs2
local Node = _G.cs2.Node
local Topology = _G.cs2.Topology
local Delivery = _G.cs2.Delivery
local mod_settings = _G.cs2.mod_settings

local strace = stlib.strace
local TRACE = stlib.TRACE
local INF = math.huge
local tremove = table.remove
local abs = math.abs
local empty = tlib.empty
local EMPTY = tlib.EMPTY_STRICT
local min = math.min

---@class Cybersyn.TrainStop
local TrainStop = class("TrainStop", Node)
_G.cs2.TrainStop = TrainStop

---@param stop_entity LuaEntity A *valid* train stop entity.
---@return Cybersyn.TrainStop
function TrainStop.new(stop_entity)
	local stop_id = stop_entity.unit_number
	local topology = cs2.get_train_topology(stop_entity.surface_index)
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
	self:update_inventory(nil, true)
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

function TrainStop:rebuild_inventory()
	local inventory = self:get_inventory()
	if not inventory then return end
	---@cast inventory Cybersyn.StopInventory
	local station_comb = self:get_combinator_with_mode("station")
	if not station_comb then return end

	if self.shared_inventory_master then
		-- Case: slave; rebuild from master
		local master = cs2.get_stop(self.shared_inventory_master)
		if master then master:rebuild_inventory() end
	else
		-- Case: normal inventory, rebuild locally
		inventory:rebuild_orders()
	end
end

---Reread this stop's inventory combinators.
---@param workload Core.Thread.Workload?
---@return Cybersyn.Combinator? station_combinator The station combinator, if any.
function TrainStop:read_inventory_combinator_inputs(workload)
	local station_combinator = nil
	for combinator_id in pairs(self.combinator_set) do
		local combinator = cs2.get_combinator(combinator_id)
		if combinator then
			local mode = combinator.mode
			if mode == "inventory" then
				combinator:read_inputs(nil, workload)
			elseif mode == "station" then
				station_combinator = combinator
				combinator:read_inputs(nil, workload)
			end
		end
	end
	return station_combinator
end

---Update this stop's inventory
---@param workload Core.Thread.Workload?
---@param is_opportunistic boolean? If `true`, this is an opportunistic update outside the main loop, e.g. when a train leaves a stop.
function TrainStop:update_inventory(workload, is_opportunistic)
	-- If shared inventory, forward to master when relevant.
	if self.shared_inventory_master then
		-- Opportunistic reread at a slave station should forward to master.
		if is_opportunistic then
			local master = cs2.get_stop(self.shared_inventory_master)
			if master then return master:update_inventory(workload, true) end
		end
		-- Otherwise, no need to read inventory at a slave station.
		return
	end

	local inventory = self:get_inventory()
	if not inventory then
		error("LOGIC ERROR: Train stop has no inventory" .. self.id)
		return
	end

	inventory:update(workload, true)
end

--------------------------------------------------------------------------------
-- SHARED INVENTORY
--------------------------------------------------------------------------------

---Get information about this stop's inventory sharing from the Thing graph.
---@return boolean is_sharing `true` if this stop is sharing inventory, `false` otherwise.
---@return Id|nil master_comb_id The shared inventory master combinator id, or `nil` if none.
---@return {[Id]: things.GraphEdge}|nil slave_combs A map of shared inventory slave combinator ids to their graph edges, or `nil` if none.
---@return Cybersyn.Combinator|nil station_comb The station combinator for this stop, or `nil` if none.
function TrainStop:get_sharing_info()
	local station_comb = self:get_combinator_with_mode("station")
	if not station_comb then return false, nil, nil, nil end
	local _, slaves, master = remote.call(
		"things",
		"get_edges",
		"cybersyn2-shared-inventory",
		station_comb.id
	)
	local master_id = master and next(master)
	if (not slaves) or (not next(slaves)) then slaves = nil end
	if master_id or slaves then
		return true, master_id, slaves, station_comb
	else
		return false, nil, nil, station_comb
	end
end

---@return Cybersyn.TrainStop[] slaves All slave stops sharing inventory from this stop.
function TrainStop:get_slaves()
	local station_comb = self:get_combinator_with_mode("station")
	if not station_comb then return EMPTY end
	local _, slaves = remote.call(
		"things",
		"get_edges",
		"cybersyn2-shared-inventory",
		station_comb.id
	)
	if (not slaves) or (not next(slaves)) then return EMPTY end
	return tlib.t_map_a(slaves, function(_, slave_comb_id)
		local slave_comb = cs2.get_combinator(slave_comb_id)
		if slave_comb then
			local slave_stop = slave_comb:get_node() --[[@as Cybersyn.TrainStop?]]
			if slave_stop and slave_stop:is_valid() then return slave_stop end
		end
	end)
end

---Share this stop's inventory to a slave.
---@param slave_comb Cybersyn.Combinator The combinator representing the slave stop.
---@return boolean linked `true` if the link was created, `false` if could not be.
function TrainStop:share_inventory_with(slave_comb)
	local is_sharing, master_comb_id, slave_combs, station_comb =
		self:get_sharing_info()
	if not station_comb then return false end
	-- Slaves can't reshare.
	if master_comb_id then return false end
	-- Already linked.
	if slave_combs and slave_combs[slave_comb.id] then return false end
	-- Create edge
	remote.call(
		"things",
		"modify_edge",
		"cybersyn2-shared-inventory",
		"create",
		station_comb.id,
		slave_comb.id
	)
	return true
end

---Stop sharing this stop's inventory.
function TrainStop:stop_sharing_inventory()
	local is_sharing, master_comb_id, slave_combs, station_comb =
		self:get_sharing_info()
	if not station_comb then return end
	-- Remove all edges
	if master_comb_id then
		remote.call(
			"things",
			"modify_edge",
			"cybersyn2-shared-inventory",
			"delete",
			master_comb_id,
			station_comb.id
		)
	end
	if slave_combs then
		self.is_master = nil
		for slave_comb_id in pairs(slave_combs) do
			remote.call(
				"things",
				"modify_edge",
				"cybersyn2-shared-inventory",
				"delete",
				station_comb.id,
				slave_comb_id
			)
		end
	end
end

---Update inventory to point to shared inventory or internal inventory as
---needed.
function TrainStop:update_inventory_sharing(master_stop)
	stlib.info(
		"Updating shared inventory for stop",
		self.id,
		"connecting to master stop",
		master_stop and master_stop.id
	)

	if master_stop then
		-- If slave station, set inventory to master stop
		if self:set_inventory(master_stop.inventory_id) then
			self:fail_all_deliveries("INVENTORY_CHANGED")
		end
	else
		-- Reset to internal inventory if we don't have a master.
		if self:set_inventory(self.created_inventory_id) then
			self:fail_all_deliveries("INVENTORY_CHANGED")
		end
	end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- Forward train_arrived events to stops
cs2.on_train_arrived(function(train, cstrain, stop)
	if cstrain and stop then stop:train_arrived(cstrain) end
end)

-- Forward train_departed events to stops
cs2.on_train_departed(function(train, cstrain, stop)
	if cstrain and stop then stop:train_departed(cstrain) end
end)

--------------------------------------------------------------------------------
-- Events: High-level shared inventory management
--------------------------------------------------------------------------------

events.bind(
	"cs2.train_stop_shared_inventory_link",
	function(slave_stop, master_stop)
		if slave_stop then slave_stop:update_inventory_sharing(master_stop) end
	end
)

events.bind(
	"cs2.train_stop_shared_inventory_unlink",
	function(slave_stop, master_stop)
		if slave_stop and slave_stop:is_valid() then
			slave_stop:update_inventory_sharing(nil)
		end
		if master_stop and master_stop:is_valid() then
			master_stop:rebuild_inventory()
		end
	end
)

--------------------------------------------------------------------------------
-- Events: Low-level shared inventory graph management
--------------------------------------------------------------------------------

---@param master Cybersyn.TrainStop
---@param slave Cybersyn.TrainStop
local function link(master, slave)
	if slave.shared_inventory_master == master.id then
		-- Already linked
		return
	end
	slave.shared_inventory_master = master.id
	slave.is_master = nil
	master.is_master = true
	events.raise("cs2.train_stop_shared_inventory_link", slave, master)
end

---@param slave Cybersyn.TrainStop
local function unlink(slave)
	if not slave.shared_inventory_master then
		-- Not linked
		return
	end
	local master = cs2.get_stop(slave.shared_inventory_master)
	slave.shared_inventory_master = nil
	if master then
		local _, _, slaves = master:get_sharing_info()
		if not slaves or not next(slaves) then master.is_master = nil end
	end
	events.raise("cs2.train_stop_shared_inventory_unlink", slave, master)
end

---@param stop Cybersyn.TrainStop
local function unlink_all(stop)
	-- If this stop is a master, unlink all slaves.
	if stop.is_master then
		local slaves = stop:get_slaves()
		for _, slave_stop in pairs(slaves) do
			unlink(slave_stop)
		end
	end
	-- If this stop is a slave, unlink from master.
	if stop.shared_inventory_master then unlink(stop) end
end

---@param stop Cybersyn.TrainStop
local function relink_all(stop)
	local is_sharing, master_comb_id, slaves = stop:get_sharing_info()
	if not is_sharing then return end
	if master_comb_id then
		local master_comb = cs2.get_combinator(master_comb_id, true)
		local master_stop = master_comb and master_comb:get_node() --[[@as Cybersyn.TrainStop?]]
		if master_stop and master_stop:is_valid() then link(master_stop, stop) end
	elseif slaves then
		for slave_comb_id in pairs(slaves) do
			local slave_comb = cs2.get_combinator(slave_comb_id, true)
			local slave_stop = slave_comb and slave_comb:get_node() --[[@as Cybersyn.TrainStop?]]
			if slave_stop and slave_stop:is_valid() then link(stop, slave_stop) end
		end
	end
end

-- Rebuild links when graph edges change.
events.bind(
	"cybersyn2-combinator-on_edge_changed",
	---@param ev things.EventData.on_edge_changed
	function(ev)
		if ev.change == "create" then
			local slave_comb = cs2.get_combinator(ev.to.id, true)
			local slave_stop = slave_comb and slave_comb:get_node() --[[@as Cybersyn.TrainStop?]]
			if slave_stop and slave_stop:is_valid() then
				local master_comb = cs2.get_combinator(ev.from.id, true)
				local master_stop = master_comb and master_comb:get_node() --[[@as Cybersyn.TrainStop?]]
				if master_stop and master_stop:is_valid() then
					-- Create link
					link(master_stop, slave_stop)
				end
			end
		elseif ev.change == "delete" then
			local slave_comb = cs2.get_combinator(ev.to.id, true)
			local slave_stop = slave_comb and slave_comb:get_node() --[[@as Cybersyn.TrainStop?]]
			if slave_stop then unlink(slave_stop) end
		end
	end
)

-- Rebuild links when status of an entity on either end of an edge changes.
events.bind(
	"cybersyn2-combinator-on_edge_status",
	---@param ev things.EventData.on_edge_status
	function(ev)
		local slave_comb = cs2.get_combinator(ev.edge.to, true)
		local slave_stop = slave_comb and slave_comb:get_node() --[[@as Cybersyn.TrainStop?]]
		local master_comb = cs2.get_combinator(ev.edge.from, true)
		local master_stop = master_comb and master_comb:get_node() --[[@as Cybersyn.TrainStop?]]
		if not slave_stop then
			-- Nothing to do here.
			return
		end
		if master_stop and master_stop:is_valid() and slave_stop:is_valid() then
			link(master_stop, slave_stop)
		else
			unlink(slave_stop)
		end
	end
)

-- Rebuild links when combinators are associated or disassociated.
cs2.on_combinator_node_associated(function(combinator, new_node, old_node)
	if combinator.mode ~= "station" then return end
	if old_node and old_node.type == "stop" then
		local stop = old_node --[[@as Cybersyn.TrainStop]]
		unlink_all(stop)
	end
	if new_node and new_node.type == "stop" then
		local stop = new_node --[[@as Cybersyn.TrainStop]]
		relink_all(stop)
	end
end)
