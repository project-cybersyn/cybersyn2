local class = require("__cybersyn2__.lib.class").class
local tlib = require("__cybersyn2__.lib.table")
local siglib = require("__cybersyn2__.lib.signal")

local cs2 = _G.cs2
local max = math.max
local network_match_or = siglib.network_match_or
local order_requested_qty = _G.cs2.order_requested_qty
local item_filter_any_quality_OR = siglib.item_filter_any_quality_OR

---@class Cybersyn.NetInventoryView: Cybersyn.View
---@field public provides SignalCounts Net provides across all matching nodes
---@field public requests SignalCounts Net true requests across all matching nodes
---@field public needed SignalCounts Net shortage of inventory less requests across all matching nodes.
---@field public inventory SignalCounts True inventory across all matching nodes.
---@field public n_prov SignalCounts
---@field public n_req SignalCounts
---@field public n_needed SignalCounts
---@field public topology_id Id
---@field public network_filter? SignalCounts
---@field public item_filter? SignalSet
---@field public skip_node boolean
local NetInventoryView = class("NetInventoryView", cs2.View)
_G.cs2.NetInventoryView = NetInventoryView

function NetInventoryView:new()
	local view = cs2.View.new(self) --[[@as Cybersyn.NetInventoryView]]
	view.skip_node = true
	view.provides = {}
	view.requests = {}
	view.needed = {}
	view.inventory = {}
	view.n_prov = {}
	view.n_req = {}
	view.n_needed = {}
	cs2.raise_view_created(self)
	return view
end

function NetInventoryView:set_filter(filter)
	self.topology_id = filter.topology_id
	self.network_filter = filter.network_filter
	self.item_filter = filter.item_filter
end

function NetInventoryView:snapshot()
	local top = cs2.get_topology(self.topology_id)
	if not top then return end
	self:enter_nodes(top)
	for _, node in pairs(storage.nodes) do
		if node.topology_id == self.topology_id then
			self:enter_node(node)
			local inv = node:get_inventory()
			if inv then
				for _, order in pairs(inv.orders) do
					self:enter_order(order, node)
					self:exit_order(order, node)
				end
			end
			self:exit_node(node)
		end
	end
	self:exit_nodes(top)
end

function NetInventoryView:read()
	return {
		provides = self.provides,
		requests = self.requests,
		needed = self.needed,
		inventory = self.inventory,
	}
end

function NetInventoryView:enter_nodes(topology)
	if topology.id == self.topology_id then
		self.provides = {}
		self.requests = {}
		self.inventory = {}
		self.needed = {}
	end
end

function NetInventoryView:enter_node(node)
	self.skip_node = true
	if node.topology_id ~= self.topology_id then return end
	if node.shared_inventory_master then return end
	local inv = node:get_inventory()
	if not inv then return end
	self.skip_node = false
	tlib.vector_add(self.inventory, 1, inv.inventory)
	self.n_prov = {}
	self.n_req = {}
	self.n_needed = {}
end

function NetInventoryView:exit_node(node)
	if self.skip_node or not self.n_prov or not self.n_req then return end
	tlib.vector_add(self.provides, 1, self.n_prov)
	tlib.vector_add(self.requests, 1, self.n_req)
	tlib.vector_add(self.needed, 1, self.n_needed)
	self.skip_node = true
end

function NetInventoryView:enter_order(order, node)
	if self.skip_node or not self.n_prov or not self.n_req then return end
	local inv = node:get_inventory()
	if not inv then return end
	if
		self.network_filter
		and (not network_match_or(order.networks, self.network_filter))
	then
		return
	end
	if node.is_producer then
		local n_prov = self.n_prov
		for item, qty in pairs(order.provides) do
			if item_filter_any_quality_OR(item, self.item_filter) then
				local n = max(n_prov[item] or 0, qty)
				if n > 0 then n_prov[item] = n end
			end
		end
	end
	if node.is_consumer then
		local n_req = self.n_req
		local n_needed = self.n_needed
		for item, qty in pairs(order.requests) do
			if item_filter_any_quality_OR(item, self.item_filter) then
				n_req[item] = max(n_req[item] or 0, qty)
				local n = order_requested_qty(order, item)
				if n > 0 then n_needed[item] = n end
			end
		end
	end
end

function NetInventoryView:exit_nodes(topology) self:update() end
