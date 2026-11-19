local mod_root = assert(arg[1], "Pass the path to the Cybersyn 2 mod directory")
package.path = mod_root .. "\\?.lua;" .. package.path

local function noop() end
local pending, next_registration = {}, 0

script = {
	mod_name = "cybersyn2",
	on_init = noop,
	on_load = noop,
	on_configuration_changed = noop,
	on_nth_tick = noop,
	register_metatable = noop,
	on_event = noop,
	register_on_object_destroyed = function(obj)
		next_registration = next_registration + 1
		obj.registration_number = next_registration
		return next_registration
	end,
}
rendering = {
	draw_line = function()
		local obj = {}
		obj.destroy = function() pending[#pending + 1] = obj.registration_number end
		return obj
	end,
}
defines = { events = { on_object_destroyed = 1 } }
bit32 = {
	extract = function(n, shift, width)
		return math.floor(n / 2 ^ shift) % 2 ^ width
	end,
	replace = function(n, value, shift, width)
		local field = 2 ^ shift
		local old = math.floor(n / field) % 2 ^ width
		return math.tointeger(n + (value % 2 ^ width - old) * field)
	end,
}
remote = { call = noop }
storage = { combinators = {}, nodes = {} }
cs2 = { Combinator = {}, combinator_modes = {}, gui = {}, mod_settings = {} }
cs2.Combinator.__index = cs2.Combinator
function cs2.Combinator:get_node() return storage.nodes[self.node_id] end
cs2.Combinator.clear_outputs = noop
function cs2.get_combinator(id) return storage.combinators[id] end
local topologies = { alpha = { id = 101 }, beta = { id = 102 } }
function cs2.get_or_create_topology_by_name(name)
	return assert(topologies[name], name)
end

package.preload["lib.core.strace"] = function()
	return {
		strace = noop,
		trace = noop,
		info = noop,
		warn = noop,
		error = noop,
		WARN = 1,
		ERROR = 2,
		TRACE = 10,
	}
end
package.preload["lib.core.relm.relm"] = function()
	return { define_element = function() return noop end, Primitive = noop }
end
package.preload["lib.core.relm.util"] = function() return {} end
package.preload["lib.core.relm.ultros"] = function() return {} end
package.preload["lib.core.scheduler"] = function()
	return { register_handler = noop }
end
package.preload["lib.core.counters"] = function() return {} end
package.preload["lib.signal"] = function() return {} end

local events = require("lib.core.event")
require("scripts.events")
require("scripts.combinator.settings")
require("scripts.combinator.mode")
require("scripts.node.base")
require("scripts.combinator.modes.station")
cs2.register_combinator_mode({ name = "inventory" })

local next_id = 0
local function node()
	next_id = next_id + 1
	local n = setmetatable({
		id = next_id,
		type = "stop",
		default_topology_id = 7,
		combinator_set = {},
		rebuilds = 0,
	}, cs2.Node)
	function n:rebuild_inventory() self.rebuilds = self.rebuilds + 1 end
	storage.nodes[n.id] = n
	return n
end

local function combinator(n, mode, signal)
	next_id = next_id + 1
	local comb = setmetatable({
		id = next_id,
		node_id = n.id,
		mode = mode,
		tag_cache = { mode = mode, topology_signal = signal and { name = signal } },
	}, cs2.Combinator)
	storage.combinators[comb.id] = comb
	n.combinator_set[comb.id] = true
	return comb
end

local function paste(comb, tags)
	events.raise("cybersyn2-combinator-on_tags_changed", {
		thing = { id = comb.id },
		cause = "engine",
		new_tags = tags,
	})
end

local tests = {}

function tests.leaving_station_mode_restores_default_topology()
	local n = node()
	local comb = combinator(n, "station", "alpha")
	n.topology_id = 101
	comb:set_mode("inventory")
	assert(n.topology_id == nil and n:get_topology_id() == 7)

	local pasted = node()
	local pasted_comb = combinator(pasted, "station", "alpha")
	pasted.topology_id = 101
	paste(
		pasted_comb,
		{ mode = "inventory", topology_signal = { name = "beta" } }
	)
	assert(pasted.topology_id == nil, "A non-station signal was applied")
end

function tests.entering_station_mode_applies_its_topology()
	local n = node()
	combinator(n, "inventory", "alpha"):set_mode("station")
	assert(n.topology_id == 101)

	local pasted = node()
	local comb = combinator(pasted, "inventory", "alpha")
	paste(comb, { mode = "station", topology_signal = { name = "beta" } })
	assert(pasted.topology_id == 102)
end

function tests.station_paste_applies_or_clears_topology()
	local n = node()
	local comb = combinator(n, "station", "alpha")
	n.topology_id = 101
	paste(comb, { mode = "station", topology_signal = { name = "beta" } })
	assert(n.topology_id == 102)
	paste(comb, { mode = "station" })
	assert(n.topology_id == nil)
end

function tests.remaining_station_topology_is_applied()
	local n = node()
	local leaving = combinator(n, "station", "alpha")
	combinator(n, "station", "beta")
	n.topology_id = 101
	leaving:set_mode("inventory")
	assert(n.topology_id == 102)
end

function tests.reassociation_recomputes_both_stops()
	local from, to = node(), node()
	local comb = combinator(from, "station", "alpha")
	combinator(from, "station", "beta")
	from.topology_id = 101
	assert(to:associate_combinator(comb))
	assert(from.topology_id == 102 and to.topology_id == 101)
	assert(from.rebuilds == 1 and to.rebuilds == 1)
end

function tests.only_structural_changes_rebuild_orders()
	local n = node()
	local comb = combinator(n, "station")
	comb:set_topology_signal({ name = "alpha" })
	assert(n.topology_id == 101 and n.rebuilds == 0)
	comb:set_primary_wire("green")
	comb:set_shared_inventory_independent_orders(true)
	assert(n.rebuilds == 2)

	local other = node()
	combinator(other, "inventory"):set_primary_wire("green")
	assert(other.rebuilds == 0, "A non-station setting rebuilt orders")
end

function tests.station_updates_are_synchronous()
	local n = node()
	local comb = combinator(n, "station", "alpha")
	comb:set_mode("inventory")
	assert(#pending == 0 and n.rebuilds == 1 and n.topology_id == nil)
end

local count = 0
for name, test in pairs(tests) do
	test()
	count = count + 1
	print("PASS " .. name)
end
print(count .. " tests passed")
