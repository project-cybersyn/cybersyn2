--------------------------------------------------------------------------------
-- Topology generation. By default, generates one topology per planetary
-- surface.
--------------------------------------------------------------------------------

-- TODO: let other mods (space exploration, trains-on-platforms) intervene in
-- how topologies are built.

local class = require("lib.core.class").class
local counters = require("lib.core.counters")
local events = require("lib.core.event")
local cs2 = _G.cs2

---@class Cybersyn.Topology
local Topology = class("Topology")
_G.cs2.Topology = Topology

---Create a new topology.
function Topology.new()
	local id = counters.next("topology")
	storage.topologies[id] =
		setmetatable({ id = id, global_combinators = {} }, Topology)
	return storage.topologies[id]
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
		topology = Topology.new()
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
	if not self.surface_index then return {} end
	return game.get_surface(self.surface_index).find_entities_filtered({
		name = cs2.COMBINATOR_NAME,
	})
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
	local t = Topology.new()
	t.surface_index = surface_index
	t.name = game.get_surface(surface_index).name
	storage.surface_index_to_train_topology[surface_index] = t.id
	cs2.raise_topologies(t, "created")
end

---Get train topology for a surface if it exists.
---@param surface_index uint
---@return Cybersyn.Topology?
function Topology.get_train_topology(surface_index)
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
			if not Topology.get_train_topology(surface.index) then
				create_train_topology(surface.index)
			end
		end
	end
end

-- At startup re-enumerate surfaces and create topologies as needed.
events.bind("on_startup", function() recheck_surfaces() end)

-- When a combinator is built, create topology if necessary
cs2.on_combinator_created(function(comb)
	if (not comb.entity) or not comb.entity.valid then return end
	local surface_index = comb.entity.surface_index
	if not Topology.get_train_topology(surface_index) then
		create_train_topology(surface_index)
	end
end, true)
