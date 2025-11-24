local class = require("lib.core.class").class
local counters = require("lib.core.counters")
local events = require("lib.core.event")
local scheduler = require("lib.core.scheduler")

local max = math.max

---@class Cybersyn.View
---@field public id Id
---@field public last_read_tick uint64 Last ticks_played when the view was read.
---@field public last_update_tick uint64 Last tick (not ticks_played) when the view was updated.
---@field public update_throttle_ticks uint64 Minimum ticks between updates.
---@field public update_task Scheduler.TaskId|nil The scheduled update task ID.
local View = class("View")
_G.cs2.View = View

---Create a new view.
function View:new()
	local id = counters.next("view")
	local obj = setmetatable({
		id = id,
		last_read_tick = game.ticks_played,
		last_update_tick = game.tick,
		update_throttle_ticks = 300,
	}, self)
	storage.views[id] = obj
	return obj
end

---Set filter and configuration information for a view.
---@param filter table
function View:set_filter(filter) end

---Take an immediate snapshot of the view from current gamestate.
---@param workload Core.Thread.Workload
function View:snapshot(workload) self:update() end

---Determine if the view is valid.
function View:is_valid() return storage.views[self.id] ~= nil end

---Destroy the view.
function View:destroy()
	storage.views[self.id] = nil
	return events.raise("cs2.view_destroyed", self)
end

function View:_update()
	self.last_update_tick = game.tick
	self.update_task = nil
	return events.raise("cs2.view_updated", self)
end

---Notify consumers that the view has been updated.
function View:update()
	if self.update_task then return end
	local tick = game.tick
	local dt = tick - self.last_update_tick
	if dt >= self.update_throttle_ticks then
		return self:_update()
	else
		self.update_task = scheduler.at_method(
			max(self.last_update_tick + self.update_throttle_ticks, tick + 1),
			self,
			"_update"
		)
	end
end

---Read current contents of the view.
function View:read() self.last_read_tick = game.ticks_played end

---@param workload Core.Thread.Workload
---@param topology Cybersyn.Topology
function View:enter_nodes(workload, topology) end

---@param workload Core.Thread.Workload
---@param node Cybersyn.Node
function View:enter_node(workload, node) end

---@param workload Core.Thread.Workload
---@param order Cybersyn.Order
---@param node Cybersyn.Node
function View:enter_order(workload, order, node) end

---@param workload Core.Thread.Workload
---@param order Cybersyn.Order
---@param node Cybersyn.Node
function View:exit_order(workload, order, node) end

---@param workload Core.Thread.Workload
---@param node Cybersyn.Node
function View:exit_node(workload, node) end

---@param workload Core.Thread.Workload
---@param topology Cybersyn.Topology
function View:exit_nodes(workload, topology) end

---@param workload Core.Thread.Workload
function View:enter_vehicles(workload) end

---Visit a Vehicle object. NOTE: vehicle may be volatile.
---@param workload Core.Thread.Workload
---@param vehicle Cybersyn.Vehicle
function View:enter_vehicle(workload, vehicle) end

---@param workload Core.Thread.Workload
---@param vehicle Cybersyn.Vehicle
function View:exit_vehicle(workload, vehicle) end

---@param workload Core.Thread.Workload
function View:exit_vehicles(workload) end

---@param workload Core.Thread.Workload
function View:enter_deliveries(workload) end

---@param workload Core.Thread.Workload
---@param delivery Cybersyn.Delivery
function View:enter_delivery(workload, delivery) end

---@param workload Core.Thread.Workload
---@param delivery Cybersyn.Delivery
function View:exit_delivery(workload, delivery) end

---@param workload Core.Thread.Workload
function View:exit_deliveries(workload) end

--------------------------------------------------------------------------------
-- Remote event rebroadcast
--------------------------------------------------------------------------------

events.bind(
	"cs2.view_created",
	function(view) script.raise_event("cybersyn2-view-created", { id = view.id }) end
)

events.bind(
	"cs2.view_destroyed",
	function(view)
		script.raise_event("cybersyn2-view-destroyed", { id = view.id })
	end
)

events.bind(
	"cs2.view_updated",
	function(view) script.raise_event("cybersyn2-view-updated", { id = view.id }) end
)
