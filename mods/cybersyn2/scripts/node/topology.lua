--------------------------------------------------------------------------------
-- Topology generation. By default, generates one topology per planetary
-- surface.
--------------------------------------------------------------------------------

-- TODO: let other mods (space exploration, trains-on-platforms) intervene in
-- how topologies are built.

local class = require("__cybersyn2__.lib.class").class
local counters = require("__cybersyn2__.lib.counters")
local cs2 = _G.cs2

---@class Cybersyn.Topology
local Topology = class("Topology")
_G.cs2.Topology = Topology

---Create a new topology.
function Topology.new()
	local id = counters.next("topology")
	storage.topologies[id] =
		setmetatable({ id = id, vehicle_type = "none" }, Topology)
	return storage.topologies[id]
end

---Get a topology by its id
---@param id Id
function Topology.get(id) return storage.topologies[id or ""] end

---@param surface_index uint
local function create_train_topology(surface_index)
	local t = Topology.new()
	t.surface_index = surface_index
	t.vehicle_type = "train"
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

---Recheck surfaces and build corresponding topologies
local function recheck_train_surfaces()
	for _, surface in pairs(game.surfaces) do
		if surface.planet then
			if not Topology.get_train_topology(surface.index) then
				create_train_topology(surface.index)
			end
		end
	end
end
_G.cs2.recheck_train_surfaces = recheck_train_surfaces

-- When config changes,re-enumerate surfaces and find matching topologies
cs2.on_configuration_changed(function(data) recheck_train_surfaces() end)
cs2.on_init(function(data) recheck_train_surfaces() end)

-- When a planet is created make a train topology.
cs2.on_surface(function(index, op)
	if op == "created" then
		local surface = game.get_surface(index)
		if
			surface
			and surface.planet
			and not Topology.get_train_topology(index)
		then
			create_train_topology(index)
		end
	end
end)
