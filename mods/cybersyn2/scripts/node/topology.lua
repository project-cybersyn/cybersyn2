--------------------------------------------------------------------------------
-- Topology generation. By default, generates one topology per planetary
-- surface.
--------------------------------------------------------------------------------

-- TODO: let other mods (space exploration, trains-on-platforms) intervene in
-- how topologies are built.

local class = require("lib.core.class").class
local counters = require("lib.core.counters")
local events = require("lib.core.event")
local tlib = require("lib.core.table")
local strace = require("lib.core.strace")
local cs2 = _G.cs2

--------------------------------------------------------------------------------
-- Topology plugin interface
--------------------------------------------------------------------------------

local route_plugins = prototypes.mod_data["cybersyn2"].data.route_plugins --[[@as {[string]: Cybersyn2.RoutePlugin} ]]

local topo_callbacks = tlib.t_map_a(
	route_plugins or tlib.EMPTY_STRICT,
	function(plugin) return plugin.train_topology_callback end
) --[[@as Core.RemoteCallbackSpec[] ]]

---Query all registered topology plugins for additional surfaces connected
---to the given surface.
---@param original_surface_id uint The surface index to query from.
---@return table<uint, boolean> #A SET of surface indices reachable from the given surface.
local function query_topo_plugins(original_surface_id)
	local surface_set = { [original_surface_id] = true }

	for _, cb in pairs(topo_callbacks) do
		if cb then
			local result = remote.call(cb[1], cb[2], original_surface_id) --[[@as table<uint, boolean>? ]]
			if result then tlib.set_union(surface_set, result) end
		end
	end

	strace.trace("query_topo_plugins", original_surface_id, surface_set)

	return surface_set
end

--------------------------------------------------------------------------------
-- Topology
--------------------------------------------------------------------------------

---@class Cybersyn.Topology
local Topology = class("Topology")
_G.cs2.Topology = Topology

---Create a new topology.
function Topology:new()
	local id = counters.next("topology")
	storage.topologies[id] =
		setmetatable({ id = id, global_combinators = {} }, self)
	return storage.topologies[id]
end

function Topology:destroy()
	strace.info("Destroying topology", self.id, self.name)
	events.raise("cs2.topology_destroyed", self)
	cs2.raise_topologies(self, "destroyed")
	storage.topologies[self.id] = nil
end

---Get a topology by its id
---@param id Id?
---@return Cybersyn.Topology?
local function get_topology(id) return storage.topologies[id or ""] end
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
		cs2.raise_topologies(topology, "created")
	end
	return topology
end
_G.cs2.get_or_create_topology_by_name = get_or_create_topology_by_name

function Topology:add_global_combinator(comb)
	if not self.global_combinators[comb.id] then
		self.global_combinators[comb.id] = true
	end
end

function Topology:remove_global_combinator(comb)
	if self.global_combinators[comb.id] then
		self.global_combinators[comb.id] = nil
	end
end

---@return LuaEntity[]
function Topology:get_combinator_entities()
	-- TODO: wtf is this for?
	error("unimplemented")
end

---Called to trigger the event indicating a topology's net inventory was
---computed by the logistics thread. Special handling must be taken to
---ensure that the event handlers, which are likely to be expensive, are
---lifted out of the main thread.
function Topology:raise_inventory_updated()
	-- TODO: implement this properly. For now, just raise the event.
	cs2.raise_topology_inventory_updated(self)
end

---@param surface_index uint
local function create_train_topology(surface_index)
	local surface_set = query_topo_plugins(surface_index)

	local t = Topology:new()
	t.name = game.get_surface(surface_index).name
	t.surface_set = surface_set
	for s_index, _ in pairs(surface_set) do
		storage.surface_index_to_train_topology[s_index] = t.id
	end

	strace.info("Created train topology", t)
	cs2.raise_topologies(t, "created")
	events.raise("cs2.topology_created", t)
end

---Get train topology for a surface if it exists.
---@param surface_index uint
---@return Cybersyn.Topology?
function _G.cs2.get_train_topology(surface_index)
	local topology_id = storage.surface_index_to_train_topology[surface_index]
	if topology_id then return storage.topologies[topology_id] end
end

---Check all surfaces for presence of cs2 combinator. Where they are present,
---create topologies.
local function recheck_surfaces()
	for _, surface in pairs(game.surfaces) do
		local combs = surface.find_entities_filtered({
			name = cs2.COMBINATOR_NAME,
		})
		if #combs > 0 then
			if not cs2.get_train_topology(surface.index) then
				create_train_topology(surface.index)
			end
		end
	end
end

-- At startup re-enumerate surfaces and create topologies as needed.
events.bind("on_startup", function() recheck_surfaces() end)

-- When a combinator is built, create topology if necessary
events.bind("cs2.combinator_status_changed", function(comb)
	if (not comb.real_entity) or not comb.real_entity.valid then return end
	local surface_index = comb.real_entity.surface_index
	if not cs2.get_train_topology(surface_index) then
		create_train_topology(surface_index)
	end
end, true)

--------------------------------------------------------------------------------
-- Retopologize
--------------------------------------------------------------------------------

function _G.cs2.rebuild_train_topologies()
	-- Destroy all pre-existing train topologies
	for _, top_id in pairs(storage.surface_index_to_train_topology) do
		local topology = storage.topologies[top_id]
		if topology then topology:destroy() end
	end
	storage.surface_index_to_train_topology = {}

	-- Regenerate topologies
	recheck_surfaces()

	-- Retopologize stops and vehicles
	events.raise("cs2.topologies_rebuilt")
end
