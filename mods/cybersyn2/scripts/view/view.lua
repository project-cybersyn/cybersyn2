local class = require("__cybersyn2__.lib.class").class
local counters = require("__cybersyn2__.lib.counters")

---@class Cybersyn.View
---@field public id Id
local View = class("View")
_G.cs2.View = View

---Create a new view.
function View:new()
	local id = counters.next("view")
	storage.views[id] = setmetatable({ id = id }, self)
	return storage.views[id]
end

---Set filter and configuration information for a view.
---@param filter table
function View:set_filter(filter) end

---Take an immediate snapshot of the view from current gamestate.
function View:snapshot() self:update() end

---Determine if the view is valid.
function View:is_valid() return storage.views[self.id] ~= nil end

---Destroy the view.
function View:destroy()
	storage.views[self.id] = nil
	cs2.raise_view_destroyed(self)
end

---Notify consumers that the view has been updated.
function View:update() return cs2.raise_view_updated(self) end

---Read current contents of the view.
function View:read() end

---@param topology Cybersyn.Topology
function View:enter_nodes(topology) end

---@param node Cybersyn.Node
function View:enter_node(node) end

---@param order Cybersyn.Order
---@param node Cybersyn.Node
function View:enter_order(order, node) end

---@param order Cybersyn.Order
---@param node Cybersyn.Node
function View:exit_order(order, node) end

---@param node Cybersyn.Node
function View:exit_node(node) end

---@param topology Cybersyn.Topology
function View:exit_nodes(topology) end

function View:enter_vehicles() end

---@param vehicle Cybersyn.Vehicle
function View:enter_vehicle(vehicle) end

---@param vehicle Cybersyn.Vehicle
function View:exit_vehicle(vehicle) end

function View:exit_vehicles() end

function View:enter_deliveries() end

---@param delivery Cybersyn.Delivery
function View:enter_delivery(delivery) end

---@param delivery Cybersyn.Delivery
function View:exit_delivery(delivery) end

function View:exit_deliveries() end

--------------------------------------------------------------------------------
-- Remote event rebroadcast
--------------------------------------------------------------------------------

_G.cs2.on_view_created(
	function(view) script.raise_event("cybersyn2-view-created", { id = view.id }) end
)

_G.cs2.on_view_destroyed(
	function(view)
		script.raise_event("cybersyn2-view-destroyed", { id = view.id })
	end
)

_G.cs2.on_view_updated(
	function(view) script.raise_event("cybersyn2-view-updated", { id = view.id }) end
)
