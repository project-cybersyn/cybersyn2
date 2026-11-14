local mod_root = assert(arg[1], "Pass the path to the Cybersyn 2 mod directory")

local STACK_SIZES = { iron = 100, copper = 100, water = 1 }

local function load_order()
	local function noop() end
	local function assign(dst, src)
		for k, v in pairs(src) do
			dst[k] = v
		end
		return dst
	end
	local cs2 = { mod_settings = {} }
	local env = setmetatable({
		cs2 = cs2,
		game = { tick = 1000 },
		table_size = function(t)
			local n = 0
			for _ in pairs(t) do
				n = n + 1
			end
			return n
		end,
	}, { __index = _G })
	env._G = env

	local modules = {
		["lib.core.table"] = {
			EMPTY = {},
			EMPTY_STRICT = {},
			assign = assign,
			t_reduce = function(t, acc, fn)
				for k, v in pairs(t) do
					acc = fn(acc, k, v)
				end
				return acc
			end,
		},
		["lib.signal"] = {
			key_to_stacksize = function(key) return STACK_SIZES[key] end,
		},
		["lib.core.thread"] = { add_workload = noop },
		["lib.core.strace"] = { trace = noop },
		["lib.types"] = {
			OrderStatus = { no_capacity = "no_capacity", fulfilled = "fulfilled" },
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
	return cs2.Order
end

local Order = load_order()

---@param fields table
local function order(fields)
	local inv = fields.inv or {}
	local o = {
		item_mode = "and",
		inventory = {
			inventory = inv,
			inflow = {},
			outflow = {},
			net = function() return inv end,
		},
		requests = {},
		requested_fluids = {},
		provides = {},
		thresh_in = {},
		thresh_min_slots = 0,
		thresh_min_fluid = 0,
		thresh_depletion_fraction = 1,
		max_item_slots = 40,
	}
	for k, v in pairs(fields) do
		o[k] = v
	end
	return setmetatable(o, Order)
end

local function provider(contents)
	return order({ item_mode = "none", inv = contents, provides = contents })
end

local tests = {}

function tests.and_items_below_train_fullness_have_no_needs()
	local req = order({
		requests = { iron = 1000 },
		thresh_in = { iron = 1000 },
		thresh_min_slots = 20,
	})
	assert(req:compute_needs() == nil, "Unsatisfiable item needs were generated")

	req.thresh_min_slots = 10
	local needs = assert(req:compute_needs(), "Satisfiable needs were dropped")
	assert(needs.items.iron == 1000)
	assert(provider({ iron = 5000 }):satisfy_needs(nil, needs))
end

function tests.and_items_total_counts_toward_train_fullness()
	local req = order({
		requests = { iron = 500, copper = 500 },
		thresh_in = { iron = 1, copper = 1 },
		thresh_min_slots = 10,
	})
	local needs = assert(req:compute_needs(), "Combined deficit was ignored")
	assert(provider({ iron = 500, copper = 500 }):satisfy_needs(nil, needs))

	req.thresh_min_slots = 11
	assert(req:compute_needs() == nil)
end

function tests.fluids_below_train_fullness_have_no_needs()
	local req = order({
		requested_fluids = { water = 10000 },
		thresh_in = { water = 1 },
		thresh_min_fluid = 25000,
	})
	assert(req:compute_needs() == nil, "Unsatisfiable fluid needs were generated")

	req.thresh_min_fluid = 10000
	local needs = assert(req:compute_needs())
	assert(provider({ water = 50000 }):satisfy_needs(nil, needs))
end

function tests.unsatisfiable_fluids_do_not_block_satisfiable_items()
	local req = order({
		requests = { iron = 2000 },
		requested_fluids = { water = 10000 },
		thresh_in = { iron = 1, water = 1 },
		thresh_min_slots = 20,
		thresh_min_fluid = 25000,
	})
	local needs = assert(req:compute_needs())
	assert(needs.items.iron == 2000)
	assert(needs.fluids == nil, "Unsatisfiable fluid needs were kept")
end

function tests.all_items_below_train_fullness_have_no_needs()
	local req = order({
		item_mode = "all",
		request_stacks = 10,
		thresh_depletion_fraction = 0,
		thresh_min_slots = 20,
	})
	assert(req:compute_needs() == nil, "Unsatisfiable ALL needs were generated")

	req.thresh_min_slots = 10
	assert(req:compute_needs().all_stacks == 10)
end

function tests.or_items_below_train_fullness_have_no_needs()
	local req = order({
		item_mode = "or",
		requests = { iron = 1 },
		request_stacks = 10,
		thresh_depletion_fraction = 0,
		thresh_min_slots = 20,
	})
	assert(req:compute_needs() == nil, "Unsatisfiable OR needs were generated")

	req.thresh_min_slots = 10
	assert(req:compute_needs().or_stacks == 10)
end

local count = 0
for name, test in pairs(tests) do
	test()
	count = count + 1
	print("PASS " .. name)
end
print(count .. " tests passed")
