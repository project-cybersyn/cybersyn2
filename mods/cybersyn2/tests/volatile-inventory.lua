local mod_root = assert(arg[1], "Pass the path to the Cybersyn 2 mod directory")

local function fixture()
	local node_created_handlers = {}
	local events_raised = {}
	local graph_edges = {}
	local counters = {}
	local game = { tick = 1000 }
	local storage = { combinators = {}, nodes = {}, inventories = {} }
	local function noop() end
	local function assign(dst, src)
		for k, v in pairs(src) do
			dst[k] = v
		end
		return dst
	end
	local cs2 = {
		lib = {},
		mod_settings = {
			warmup_time = 1,
			default_auto_threshold_fraction = 1,
			default_train_fullness_fraction = 0,
			default_netmask = 1,
		},
		on_node_created = function(handler)
			node_created_handlers[#node_created_handlers + 1] = handler
		end,
		raise_node_created = function(node)
			for _, handler in ipairs(node_created_handlers) do
				handler(node)
			end
		end,
		on_combinator_destroyed = noop,
		on_combinator_node_associated = noop,
		on_train_arrived = noop,
		on_train_departed = noop,
		raise_node_data_changed = noop,
		query_node_topology_plugins = noop,
		get_or_create_train_topology = function() return { id = 1 } end,
	}
	local env = setmetatable({
		cs2 = cs2,
		game = game,
		storage = storage,
		bit32 = { band = noop },
		table_size = function(t)
			local n = 0
			for _ in pairs(t) do
				n = n + 1
			end
			return n
		end,
		defines = {
			entity_status = { working = 1 },
			wire_connector_id = {
				combinator_input_red = 1,
				combinator_input_green = 2,
				combinator_output_red = 3,
				combinator_output_green = 4,
			},
			wire_origin = { script = 1 },
			rail_direction = { back = 1 },
		},
	}, { __index = _G })
	env._G = env

	local modules = {
		["lib.core.table"] = {
			EMPTY = {},
			EMPTY_STRICT = {},
			empty = {},
			assign = assign,
			t_map_a = function(t, fn)
				local out = {}
				for k, v in pairs(t) do
					local result = fn(v, k)
					if result ~= nil then out[#out + 1] = result end
				end
				return out
			end,
		},
		["lib.core.event"] = {
			bind = noop,
			raise = function(name, ...)
				events_raised[#events_raised + 1] = { name, ... }
			end,
		},
		["lib.core.strace"] = {
			strace = noop,
			trace = noop,
			info = noop,
			warn = noop,
			error = noop,
			WARN = 1,
			ERROR = 2,
			TRACE = 3,
		},
		["lib.core.counters"] = {
			next = function(name)
				counters[name] = (counters[name] or 0) + 1
				return counters[name]
			end,
		},
		["lib.core.scheduler"] = { register_handler = noop },
		["lib.core.thread"] = {
			add_workload = function(workload, amount)
				if workload then workload.workload = workload.workload + amount end
			end,
		},
		["lib.core.math.pos"] = {},
		["lib.core.math.numeric"] = { clamp = function(x) return x or 0 end },
		["lib.core.math.era-counter"] = {
			update_era_counter = noop,
			create_or_update_era_counter = noop,
		},
		["lib.signal"] = {
			signals_to_signal_counts = function(signals) return signals end,
			classify_key = function() return "cargo", "item" end,
			key_is_cargo = function() return true end,
			key_is_fluid = function() return false end,
			key_to_stacksize = function() return 1 end,
		},
		["lib.types"] = {
			OrderStatus = { no_capacity = "no_capacity", unknown = "unknown" },
		},
		["__0-things__.client.client"] = {
			combinators_v1 = {},
			parent_child_v1 = {},
			triggers_v1 = { arm_trigger = noop },
			graph_v1 = { get_edges = function(_, id) return graph_edges[id] end },
		},
	}
	env.require = function(name)
		if modules[name] ~= nil then return modules[name] end
		local path = mod_root .. "\\" .. name:gsub("%.", "\\") .. ".lua"
		local result = assert(loadfile(path, "t", env))()
		modules[name] = result or true
		return modules[name]
	end

	env.require("scripts.logistics.order")
	env.require("scripts.logistics.inventory")
	env.require("scripts.combinator.base")
	env.require("scripts.node.base")
	env.require("scripts.node.stop.base")
	cs2.combinator_modes.station =
		{ is_input = true, independent_input_wires = true }
	cs2.combinator_modes.inventory =
		{ is_input = true, independent_input_wires = true }
	cs2.get_combinator_mode = function(mode) return cs2.combinator_modes[mode] end
	cs2.iterate_combinators = function(node)
		local function iter(set, last)
			local id = next(set, last)
			if id then return id, cs2.get_combinator(id, true) end
		end
		return iter, node.combinator_set, nil
	end

	local Combinator = cs2.Combinator
	for _, name in ipairs({
		"allow_departure_signal",
		"force_departure_signal",
		"signal_depletion_percentage",
		"signal_fullness_percentage",
		"signal_reserved_slots",
		"signal_reserved_fluid",
		"signal_spillover",
		"pr",
		"auto_threshold_percent",
		"train_fullness_percent",
		"reserved_slots",
		"reserved_capacity",
		"spillover",
		"inactivity_timeout",
		"inactivity_mode",
		"disable_cargo_condition",
		"produce_single_item",
		"fullness_when_providing",
		"order_primary_network",
		"order_primary_stacked_requests",
		"order_primary_round_to_stacks",
		"order_primary_reservation_type",
		"order_secondary_network",
		"order_secondary_stacked_requests",
		"order_secondary_round_to_stacks",
		"order_secondary_reservation_type",
		"shared_inventory_independent_orders",
	}) do
		Combinator["get_" .. name] = noop
	end
	Combinator.get_primary_wire = function() return "red" end
	Combinator.get_order_primary_network_matching_mode = function() return "or" end
	Combinator.get_order_secondary_network_matching_mode = function() return "or" end

	local class = env.require("lib.core.class").class
	local StateMachine = env.require("lib.core.state-machine")
	cs2.LogisticsThread = class("TestLogisticsThread", StateMachine)
	env.require("scripts.tasks.dispatch-loop.poll-nodes")

	local f = { game = game, events = events_raised }
	local next_entity, next_thing = 100, 1000
	function f.stop(parked)
		next_entity = next_entity + 1
		local entity = {
			valid = true,
			unit_number = next_entity,
			surface_index = 1,
			train_stop_priority = 50,
			parked = parked,
			volatility_checks = 0,
		}
		entity.get_stopped_train = function()
			entity.volatility_checks = entity.volatility_checks + 1
			return entity.parked and {} or nil
		end
		return cs2.TrainStop.new(entity)
	end
	function f.combinator(stop, mode, red, green)
		next_thing = next_thing + 1
		local entity = {
			valid = true,
			status = env.defines.entity_status.working,
			get_signals = function(wire)
				if wire == env.defines.wire_connector_id.combinator_input_red then
					return red
				end
				return green
			end,
		}
		local comb =
			Combinator:new({ id = next_thing, status = "real", entity = entity })
		comb.mode = mode
		comb.node_id = stop.id
		stop.combinator_set[comb.id] = true
		return comb
	end
	function f.share(master, slaves)
		local master_comb = master:get_combinator_with_mode("station")
		graph_edges[master_comb.id] = {}
		master.is_master = true
		for _, slave in ipairs(slaves) do
			local slave_comb = slave:get_combinator_with_mode("station")
			graph_edges[master_comb.id][slave_comb.id] = true
			slave.shared_inventory_master = master.id
			slave.inventory_id = master.inventory_id
		end
		master:rebuild_inventory()
	end
	function f.advance(ticks) game.tick = game.tick + (ticks or 1) end
	function f.poll(stop, before_cleanup, existing_thread)
		local thread = existing_thread
			or setmetatable({
				workload_counter = { workload = 0 },
				providers = {},
				requesters = {},
			}, cs2.LogisticsThread)
		thread.state = "poll_train_stop"
		thread.node = stop
		thread.node_index = 1
		thread.nodes = { stop }
		thread:poll_train_stop()
		if thread.state == "poll_train_stop_update_inventory" then
			thread:poll_train_stop_update_inventory()
		end
		if before_cleanup then before_cleanup(thread) end
		while thread.state == "poll_train_stop_classify_inventory" do
			thread:poll_train_stop_classify_inventory()
		end
		assert(thread.state == "poll_nodes", "Unexpected final polling state")
		return thread
	end
	function f.order(stop, node_id, comb_id, wire)
		for _, order in ipairs(stop:get_orders()) do
			if
				order.node_id == node_id
				and order.combinator_id == comb_id
				and order.combinator_input == wire
			then
				return order
			end
		end
		error("Expected order was not rebuilt")
	end
	return f
end

local tests = {}

function tests.volatile_station_waits_for_a_safe_read()
	local f = fixture()
	local stop = f.stop(true)
	local station = f.combinator(stop, "station", { iron = 100 }, { iron = 17 })
	local inventory = f.combinator(stop, "inventory", { copper = 5 }, {})
	stop:rebuild_inventory()
	f.advance(60)

	f.poll(stop)
	assert(stop:is_dirty(), "A volatile station was marked clean")
	assert(inventory.inputs_dirty, "Volatile inventory inputs were read")
	assert(not f.order(stop, stop.id, inventory.id, "red").provides.copper)
	f.advance()
	f.poll(stop)
	assert(stop:is_dirty(), "A volatile station was marked clean on retry")

	stop.entity.parked = false
	f.advance()
	f.poll(stop)
	assert(not stop:is_dirty(), "A successful read did not clean the station")
	assert(not inventory.inputs_dirty)
	assert(f.order(stop, stop.id, station.id, "green").provides.iron == 17)
	assert(f.order(stop, stop.id, inventory.id, "red").provides.copper == 5)
end

function tests.shared_stations_wait_for_the_master_to_read()
	for _, train_at in ipairs({ "master", "slave" }) do
		local f = fixture()
		local master = f.stop(train_at == "master")
		local parked_slave = f.stop(train_at == "slave")
		local other_slave = f.stop(false)
		local master_comb = f.combinator(
			master,
			"station",
			{ iron = 100 },
			{ iron = 17 }
		)
		f.combinator(parked_slave, "station", {}, {})
		f.combinator(other_slave, "station", {}, {})
		f.share(master, { parked_slave, other_slave })
		f.advance(60)

		f.poll(other_slave)
		f.poll(master)
		f.poll(parked_slave)
		assert(
			master:is_dirty() and parked_slave:is_dirty() and other_slave:is_dirty()
		)

		local parked_stop = train_at == "master" and master or parked_slave
		parked_stop.entity.parked = false
		f.advance()
		f.poll(other_slave)
		assert(other_slave:is_dirty(), "A slave was cleaned before the shared read")
		f.poll(master)
		assert(not master:is_dirty())
		assert(
			f.order(master, other_slave.id, master_comb.id, "green").provides.iron
				== 17
		)
		f.poll(other_slave)
		f.poll(parked_slave)
		assert(not other_slave:is_dirty() and not parked_slave:is_dirty())
	end
end

function tests.shared_slave_uses_recorded_master_result_without_checks()
	local f = fixture()
	local master, slave = f.stop(false), f.stop(false)
	f.combinator(master, "station", { iron = 100 }, { iron = 17 })
	f.combinator(slave, "station", {}, {})
	f.share(master, { slave })
	f.advance(60)

	f.poll(slave)
	assert(slave:is_dirty(), "A slave was cleaned before the first shared read")
	assert(master.entity.volatility_checks == 0)
	assert(slave.entity.volatility_checks == 0)

	f.poll(master)
	assert(master:get_inventory().last_read_complete)
	master.entity.parked = true
	f.poll(slave)
	assert(not slave:is_dirty(), "A slave ignored the successful shared read")
	assert(master.entity.volatility_checks == 1, "The slave rechecked volatility")
	assert(slave.entity.volatility_checks == 1, "The slave rechecked volatility")
end

function tests.train_arrival_after_read_does_not_change_result()
	local f = fixture()
	local stop = f.stop(false)
	f.combinator(stop, "station", { iron = 100 }, { iron = 17 })
	stop:rebuild_inventory()
	f.advance(60)

	f.poll(stop, function() stop.entity.parked = true end)
	assert(not stop:is_dirty(), "A successful read was invalidated at cleanup")
	assert(stop.entity.volatility_checks == 1, "Cleanup rechecked volatility")
	assert(f.events[#f.events][1] == "cs2.node_polled")
end

function tests.failed_read_stays_dirty_if_train_leaves_before_cleanup()
	local f = fixture()
	local stop = f.stop(true)
	f.combinator(stop, "station", { iron = 100 }, { iron = 17 })
	stop:rebuild_inventory()
	f.advance(60)

	f.poll(stop, function() stop.entity.parked = false end)
	assert(stop:is_dirty(), "A failed read was forgotten when the train left")
	assert(stop.entity.volatility_checks == 1, "Cleanup rechecked volatility")
	f.advance()
	f.poll(stop)
	assert(not stop:is_dirty())
end

function tests.later_success_does_not_erase_this_polls_failed_read()
	local f = fixture()
	local stop = f.stop(true)
	f.combinator(stop, "station", { iron = 100 }, { iron = 17 })
	stop:rebuild_inventory()
	f.advance(60)

	f.poll(stop, function()
		stop.entity.parked = false
		f.advance()
		assert(stop:update_inventory(nil, true))
	end)
	assert(stop:get_inventory().last_read_complete)
	assert(stop:is_dirty(), "A later successful read erased this poll's failure")
	assert(stop.entity.volatility_checks == 2, "Cleanup rechecked volatility")
	f.poll(stop)
	assert(
		not stop:is_dirty(),
		"The failed-read result leaked into the next poll"
	)
end

function tests.multiple_read_attempts_latch_any_failure()
	local f = fixture()
	local stop = f.stop(true)
	f.combinator(stop, "station", { iron = 100 }, { iron = 17 })
	stop:rebuild_inventory()
	f.advance(60)

	f.poll(stop, function(thread)
		stop.entity.parked = false
		f.advance()
		thread:poll_train_stop_update_inventory()
	end)
	assert(stop:get_inventory().last_read_complete)
	assert(stop:is_dirty(), "A second read erased the first read's failure")
	assert(stop.entity.volatility_checks == 2, "Cleanup rechecked volatility")
end

function tests.failed_read_does_not_leak_to_next_node()
	local f = fixture()
	local volatile, safe = f.stop(true), f.stop(false)
	f.combinator(volatile, "station", { iron = 100 }, { iron = 17 })
	f.combinator(safe, "station", { copper = 100 }, { copper = 5 })
	volatile:rebuild_inventory()
	safe:rebuild_inventory()
	f.advance(60)

	local thread = f.poll(volatile)
	assert(volatile:is_dirty())
	assert(thread.node_inventory_read_failed == nil)
	f.poll(safe, nil, thread)
	assert(not safe:is_dirty(), "A previous node's read failure leaked")
end

function tests.skipped_station_does_not_check_volatility()
	local f = fixture()
	local stop = f.stop(true)
	f.combinator(stop, "inventory", { copper = 5 }, {})
	f.advance(60)
	f.poll(stop)
	assert(
		stop.entity.volatility_checks == 0,
		"A skipped read checked volatility"
	)
end

function tests.deferred_combinator_read_keeps_station_dirty()
	local f = fixture()
	local stop = f.stop(true)
	f.combinator(stop, "station", { iron = 100 }, { iron = 17 })
	local comb = f.combinator(stop, "inventory", { copper = 5 }, {})
	stop:rebuild_inventory()
	f.advance(60)
	f.poll(stop)
	assert(stop:is_dirty())

	stop.entity.parked = false
	f.advance()
	stop:get_inventory():update(nil, false, false)
	assert(not stop:get_inventory().last_read_complete)
	comb.last_read_tick = f.game.tick
	f.poll(stop)
	assert(stop:is_dirty(), "A deferred combinator read was treated as complete")
	f.advance()
	f.poll(stop)
	assert(not stop:is_dirty())
	assert(f.order(stop, stop.id, comb.id, "red").provides.copper == 5)
end

function tests.shared_deferred_input_keeps_stations_dirty()
	local f = fixture()
	local master, slave = f.stop(false), f.stop(true)
	f.combinator(master, "station", { iron = 100 }, { iron = 17 })
	local station = f.combinator(slave, "station", {}, {})
	station.get_shared_inventory_independent_orders = function() return true end
	local comb = f.combinator(slave, "inventory", { copper = 5 }, {})
	f.share(master, { slave })
	f.advance(60)
	f.poll(slave)
	f.poll(master)
	assert(master:is_dirty() and slave:is_dirty())

	slave.entity.parked = false
	f.advance()
	comb.last_read_tick = f.game.tick
	f.poll(master)
	f.poll(slave)
	assert(master:is_dirty() and slave:is_dirty())
	assert(not f.order(master, slave.id, comb.id, "red").provides.copper)

	f.advance()
	f.poll(master)
	f.poll(slave)
	assert(not master:is_dirty() and not slave:is_dirty())
	assert(f.order(master, slave.id, comb.id, "red").provides.copper == 5)
end

function tests.departure_performs_an_opportunistic_read()
	local f = fixture()
	local stop = f.stop(true)
	local station = f.combinator(stop, "station", { iron = 100 }, { iron = 17 })
	local comb = f.combinator(stop, "inventory", { copper = 5 }, {})
	stop:rebuild_inventory()
	f.advance(60)
	f.poll(stop)
	assert(stop:is_dirty())

	stop.entity.parked = false
	f.advance()
	stop:train_departed(nil, {})
	assert(stop:is_dirty(), "An opportunistic read cleaned the station")
	assert(stop:get_inventory().last_read_complete)
	assert(f.order(stop, stop.id, station.id, "green").provides.iron == 17)
	assert(f.order(stop, stop.id, comb.id, "red").provides.copper == 5)
	f.poll(stop)
	assert(not stop:is_dirty())
end

function tests.nonvolatile_poll_and_revision_changes()
	local f = fixture()
	local stop = f.stop(false)
	f.combinator(stop, "station", { iron = 100 }, { iron = 17 })
	stop:rebuild_inventory()
	f.advance(60)
	f.poll(stop, function() stop:mark_dirty() end)
	assert(stop:is_dirty(), "A newer revision was marked clean")
	f.advance()
	f.poll(stop)
	assert(not stop:is_dirty(), "A non-volatile station did not become clean")
end

local count = 0
for name, test in pairs(tests) do
	test()
	count = count + 1
	print("PASS " .. name)
end
print(count .. " tests passed")
