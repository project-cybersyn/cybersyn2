--------------------------------------------------------------------------------
-- Topology generation. By default, generates one topology per planetary
-- surface.
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local counters = require("lib.core.counters")
local events = require("lib.core.event")
local tlib = require("lib.core.table")
local strace = require("lib.core.strace")
local cs2 = _G.cs2

--------------------------------------------------------------------------------
-- Topology plugin interface
--------------------------------------------------------------------------------

local v_topo_plugins =
	prototypes.mod_data["cybersyn2"].data.vehicle_topology_plugins --[[@as Core.RemoteCallbackSpec[] ]]

local n_topo_plugins =
	prototypes.mod_data["cybersyn2"].data.node_topology_plugins --[[@as Core.RemoteCallbackSpec[] ]]

---@param vehicle Cybersyn.Vehicle
---@return Id? topology_id Id of the default topology to assign to this vehicle.
function cs2.query_vehicle_topology_plugins(vehicle)
	if #v_topo_plugins == 0 then return nil end
	local lua_train
	if vehicle.type == "train" then
		---@cast vehicle Cybersyn.Train
		lua_train = vehicle.lua_train
	end
	for i = 1, #v_topo_plugins do
		local plugin = v_topo_plugins[i]
		local result = remote.call(plugin[1], plugin[2], vehicle.id, lua_train) --[[@as Id? ]]
		if result then return result end
	end
end

---@param node Cybersyn.Node
---@return Id? topology_id Id of the default topology to assign to this node.
function cs2.query_node_topology_plugins(node)
	if #n_topo_plugins == 0 then return nil end
	local train_stop
	if node.type == "stop" then
		---@cast node Cybersyn.TrainStop
		train_stop = node.entity
	end
	for i = 1, #n_topo_plugins do
		local plugin = n_topo_plugins[i]
		local result = remote.call(plugin[1], plugin[2], node.id, train_stop) --[[@as Id? ]]
		if result then return result end
	end
end

--------------------------------------------------------------------------------
-- Topology
--------------------------------------------------------------------------------

---@class (partial) Cybersyn.Topology
local Topology = class("Topology")
_G.cs2.Topology = Topology

---Create a new topology.
function Topology:new()
	local id = counters.next("topology")
	storage.topologies[id] = setmetatable({ id = id }, self)
	return storage.topologies[id]
end

function Topology:destroy()
	strace.info("Destroying topology", self.id, self.name)
	events.raise("cs2.topology_destroyed", self)
	storage.topologies[self.id] = nil
end

---Get a topology by its id
---@param id Id?
---@return Cybersyn.Topology?
local function get_topology(id)
	if not id then return nil end
	return storage.topologies[id]
end
Topology.get = get_topology
_G.cs2.get_topology = get_topology

---@param name string
---@return Cybersyn.Topology?
local function get_topology_by_name(name)
	-- XXX: linear search here, but should be fine as it is rarely called.
	for _, topology in pairs(storage.topologies) do
		if topology.name == name then return topology end
	end
end
_G.cs2.get_topology_by_name = get_topology_by_name

---@param name string
---@return Cybersyn.Topology
local function get_or_create_topology_by_name(name)
	local topology = get_topology_by_name(name)
	if not topology then
		topology = Topology:new()
		topology.name = name
		events.raise("cs2.topology_created", topology)
	end
	return topology
end
_G.cs2.get_or_create_topology_by_name = get_or_create_topology_by_name

---@param id Id? Topology id
---@return string? name The name of the topology, if it exists.
function cs2.get_topology_name(id)
	local topology = storage.topologies[id or 0]
	return topology and topology.name
end

---@param surface_index uint
---@return Cybersyn.Topology? topology The topology for the given surface, if any.
local function create_train_topology(surface_index)
	local surface = game.get_surface(surface_index)
	if not surface then
		error(
			"LOGIC ERROR: create_train_topology called with invalid surface index "
				.. surface_index
		)
		return nil
	end

	local t = Topology:new()
	t.name = surface.name
	storage.surface_index_to_train_topology[surface_index] = t.id

	strace.info("Created train topology", t)
	events.raise("cs2.topology_created", t)
	return t
end

---Get train topology for a surface if it exists.
---@param surface_index uint
---@return Cybersyn.Topology?
local function get_train_topology(surface_index)
	local topology_id = storage.surface_index_to_train_topology[surface_index]
	if topology_id then return storage.topologies[topology_id] end
end
cs2.get_train_topology = get_train_topology

local function get_or_create_train_topology(surface_index)
	local topology = get_train_topology(surface_index)
	if not topology then topology = create_train_topology(surface_index) end
	return topology
end
cs2.get_or_create_train_topology = get_or_create_train_topology

--------------------------------------------------------------------------------
-- Retopologize
--------------------------------------------------------------------------------

function cs2.retopologize()
	strace.warn("cs2.retopologize(): Retopologizing all nodes and vehicles...")

	-- Re-query default topologies for all nodes and vehicles.
	for _, node in pairs(storage.nodes) do
		node:compute_default_topology()
	end
	for _, vehicle in pairs(storage.vehicles) do
		vehicle:compute_default_topology()
	end

	-- Mark topologies that are still in use
	local used_topologies = {}
	for _, node in pairs(storage.nodes) do
		local topology_id = node:get_topology_id()
		if topology_id then used_topologies[topology_id] = true end
	end
	for _, vehicle in pairs(storage.vehicles) do
		local topology_id = vehicle:get_topology_id()
		if topology_id then used_topologies[topology_id] = true end
	end

	-- Destroy topologies that are no longer in use
	for id, topology in pairs(storage.topologies) do
		if not used_topologies[id] then topology:destroy() end
	end
end
