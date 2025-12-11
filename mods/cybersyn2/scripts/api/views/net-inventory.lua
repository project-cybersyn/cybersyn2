local class = require("lib.core.class").class
local tlib = require("lib.core.table")
local siglib = require("lib.signal")
local thread_lib = require("lib.core.thread")
local events = require("lib.core.event")

local cs2 = _G.cs2
local View = _G.cs2.View
local add_workload = thread_lib.add_workload
local table_size = _G.table_size
local max = math.max
local network_match_or = siglib.network_match_or
local order_requested_qty = _G.cs2.order_requested_qty
local item_filter_any_quality_OR = siglib.item_filter_any_quality_OR
local EMPTY = tlib.empty

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
	events.raise("cs2.view_created", view)
	return view
end

function NetInventoryView:set_filter(filter)
	self.topology_id = filter.topology_id
	self.network_filter = filter.network_filter
	self.item_filter = filter.item_filter
end

function NetInventoryView:snapshot(workload)
	local top = cs2.get_topology(self.topology_id)
	if not top then return end
	self:enter_nodes(workload, top)
	for _, node in pairs(storage.nodes) do
		if node.topology_id == self.topology_id then
			self:enter_node(workload, node)
			local inv = node:get_inventory()
			if inv then
				for _, order in pairs(inv.orders) do
					self:enter_order(workload, order, node)
					self:exit_order(workload, order, node)
				end
			end
			self:exit_node(workload, node)
		end
	end
	self:exit_nodes(workload, top)
end

function NetInventoryView:enter_nodes(workload, topology)
	if topology.id == self.topology_id then
		self.provides = {}
		self.requests = {}
		self.inventory = {}
		self.needed = {}
	end
end

function NetInventoryView:enter_node(workload, node)
	-- Skip nodes with potentially invalid inventory
	self.skip_node = true
	if node.topology_id ~= self.topology_id then return end
	local inv = nil
	local ninv = node:get_inventory() or EMPTY
	-- Don't count slave inventories
	if node.type == "stop" then
		---@cast node Cybersyn.TrainStop
		if node.shared_inventory_master then
			inv = nil
		else
			inv = ninv.inventory
		end
	else
		inv = ninv.inventory
	end
	-- Node is live, clear skip flag.
	self.skip_node = false
	if inv then
		tlib.vector_add(self.inventory, 1, inv)
		add_workload(workload, 0.5 * table_size(inv))
	end
	self.n_prov = {}
	self.n_req = {}
	self.n_needed = {}
end

function NetInventoryView:exit_node(workload, node)
	if self.skip_node or not self.n_prov or not self.n_req then return end
	tlib.vector_add(self.provides, 1, self.n_prov)
	add_workload(workload, 0.5 * table_size(self.n_prov))
	tlib.vector_add(self.requests, 1, self.n_req)
	add_workload(workload, 0.5 * table_size(self.n_req))
	tlib.vector_add(self.needed, 1, self.n_needed)
	add_workload(workload, 0.5 * table_size(self.n_needed))
	-- Set skip flag until we enter another live node.
	self.skip_node = true
end

function NetInventoryView:exit_order(workload, order, node)
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
		for item, _ in pairs(order.provides) do
			if item_filter_any_quality_OR(item, self.item_filter) then
				local n = max(n_prov[item] or 0, order:get_provided_qty(item))
				if n > 0 then n_prov[item] = n end
			end
		end
		add_workload(workload, table_size(order.provides))
	end
	if node.is_consumer then
		local n_req = self.n_req
		local n_needed = self.n_needed
		local needs = order.needs
		for item in pairs(order.requested_fluids) do
			if item_filter_any_quality_OR(item, self.item_filter) then
				local req, needed = order:get_requested_qty(item)
				local max_needed = max(n_needed[item] or 0, needed)
				n_req[item] = max(n_req[item] or 0, req)
				if max_needed > 0 then n_needed[item] = max_needed end
			end
		end
		add_workload(workload, 2 * table_size(order.requested_fluids))
		for item in pairs(order.requests) do
			if item_filter_any_quality_OR(item, self.item_filter) then
				local req, needed = order:get_requested_qty(item)
				local max_needed = max(n_needed[item] or 0, needed)
				n_req[item] = max(n_req[item] or 0, req)
				if max_needed > 0 then n_needed[item] = max_needed end
			end
		end
		add_workload(workload, 2 * table_size(order.requests))
	end
end

function NetInventoryView:exit_nodes(workload, topology)
	if topology.id == self.topology_id then
		self:update({
			provides = self.provides,
			requests = self.requests,
			needed = self.needed,
			inventory = self.inventory,
		})
	end
end
