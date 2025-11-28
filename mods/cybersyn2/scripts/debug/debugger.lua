--------------------------------------------------------------------------------
-- Debugger GUI
--------------------------------------------------------------------------------

local relm = require("lib.core.relm.relm")
local relm_table = require("lib.core.relm.table-renderer")
local ultros = require("lib.core.relm.ultros")
local relm_helpers = require("lib.core.relm.util")
local tlib = require("lib.core.table")
local strace_lib = require("lib.core.strace")
local signal = require("lib.signal")
local thread = require("lib.core.thread")
local cs2 = _G.cs2

local strformat = string.format
local tconcat = table.concat
local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local default_renderer = relm_table.default_renderer
local EMPTY = tlib.EMPTY_STRICT

local DISPLAYED_LIMIT = 1000

local function rt_kv(kt, vt, limit)
	return function(tbl)
		local entries = {}
		local i = 1
		for k, v in pairs(tbl) do
			if i > (limit or DISPLAYED_LIMIT) then break end
			i = i + 1
			entries[#entries + 1] = kt(k) .. ": " .. vt(v)
		end
		return "{" .. tconcat(entries, ", ") .. "}"
	end
end

local function rt_array(et, limit)
	return function(arr)
		local entries = {}
		for i = 1, #arr do
			if i > (limit or DISPLAYED_LIMIT) then break end
			entries[#entries + 1] = et(arr[i])
		end
		return "[" .. tconcat(entries, ", ") .. "]"
	end
end

local function rt_set(et, limit)
	return function(set)
		local entries = {}
		local i = 1
		for elt, _ in pairs(set) do
			if i > (limit or DISPLAYED_LIMIT) then break end
			i = i + 1
			entries[#entries + 1] = et(elt)
		end
		return "<" .. tconcat(entries, ", ") .. ">"
	end
end

local rt_val = strace_lib.stringify

local function rt_field(k, ft)
	return function(tbl) return k .. ":" .. (ft or strace_lib.stringify)(tbl[k]) end
end

local function rt_fields(...)
	local fns = {}
	for i = 1, select("#", ...), 2 do
		fns[#fns + 1] = rt_field(select(i, ...), select(i + 1, ...))
	end
	return function(tbl)
		local res = {}
		for i = 1, #fns do
			res[i] = fns[i](tbl)
		end
		return "{" .. tconcat(res, ", ") .. "}"
	end
end

local function rt(f)
	return function(k, v)
		return ultros.BoldLabel(k), ultros.RtMultilineLabel(f(v))
	end
end

local function rt_item_icon(key) return signal.key_to_richtext(key) end

local renderers = {
	topologies = rt(rt_array(rt_field("id"), DISPLAYED_LIMIT)),
	nodes = rt(rt_array(rt_field("id"), DISPLAYED_LIMIT)),
	providers = rt(
		rt_kv(rt_item_icon, rt_array(rt_field("node_id"), DISPLAYED_LIMIT))
	),
	requesters = rt(
		rt_kv(rt_item_icon, rt_array(rt_field("node_id"), DISPLAYED_LIMIT))
	),
	allocations = rt(
		rt_array(
			rt_fields(
				"from",
				rt_field("id"),
				"to",
				rt_field("id"),
				"item",
				rt_item_icon,
				"qty",
				rt_val,
				"prio",
				rt_val
			)
		)
	),
	allocs_from = rt(
		rt_kv(
			rt_val,
			rt_array(rt_fields("item", rt_item_icon, "qty", rt_val), DISPLAYED_LIMIT)
		)
	),
	avail_trains = rt(rt_set(rt_val, DISPLAYED_LIMIT)),
}

local LoopState = relm.define_element({
	name = "LogisticsLoopDebugger.State",
	render = function(props, state)
		-- TODO: factor logistics thread id up to a prop
		local data = cs2.debug.get_logistics_thread()
		if not data then return nil end
		local tstate = data.state
		local children = {
			ultros.BoldLabel("state"),
			ultros.Label(tstate),
		}
		for k, v in pairs(data) do
			if
				k ~= "state"
				and k ~= "paused"
				and k ~= "stepped"
				and type(v) ~= "function"
			then
				local renderer = renderers[k] or default_renderer
				tlib.append(children, renderer(k, v))
			end
		end
		return relm.Primitive({
			type = "table",
			horizontally_stretchable = true,
			column_count = 2,
		}, children)
	end,
	message = function(me, payload)
		if payload.key == "on_debug_loop" then
			relm.paint(me)
			return true
		end
		return false
	end,
})

local LoopDebugger = relm.define_element({
	name = "Cybersyn.LoopDebugger",
	render = function(props, state)
		return VF({}, {
			Pr({
				type = "scroll-pane",
				direction = "vertical",
				width = 400,
				height = 400,
			}, {
				LoopState(),
			}),
			HF({
				ultros.Button({ caption = "Pause", on_click = "pause" }),
				ultros.Button({ caption = "Step", on_click = "step" }),
			}),
		})
	end,
	message = function(me, payload, props)
		-- TODO: factor logistics thread id up to a prop
		local data = cs2.debug.get_logistics_thread() or {}
		if payload.key == "pause" then
			data.paused = not data.paused
			return true
		elseif payload.key == "step" then
			data.stepped = true
			return true
		end
		return false
	end,
})

--------------------------------------------------------------------------------
-- Strace configurator
--------------------------------------------------------------------------------

local function decode_filter(filter)
	local out = {}
	if not filter then return out end
	for k, v in pairs(filter) do
		if type(v) == "table" then
			for sub_k, _ in pairs(v) do
				out[#out + 1] = { k, sub_k }
			end
		elseif v == true or v == false then
			out[#out + 1] = { k, tostring(v) }
		else
			out[#out + 1] = { k, tostring(v) }
		end
	end
	return out
end

local function encode_filter(inputs)
	if not inputs then return nil end
	local out = {}
	for _, pair in pairs(inputs) do
		if pair[1] and pair[1] ~= "" and pair[2] ~= "" then
			if pair[2] == "true" then
				out[pair[1]] = true
			elseif pair[2] == "false" then
				out[pair[1]] = false
			elseif out[pair[1]] then
				out[pair[1]][pair[2]] = true
			else
				out[pair[1]] = { [pair[2]] = true }
			end
		end
	end
	if table_size(out) > 0 then
		return out
	else
		return nil
	end
end

local StraceFilters = relm.define_element({
	name = "Cybersyn.StraceFilters",
	render = function(props, state)
		local filters = state.filters or {}
		local children = {}
		local key, fpair
		for i = 1, state.n do
			key, fpair = next(filters, key)
			children[i] = HF({
				ultros.gather({
					ultros.Input({ value = fpair and fpair[1] or "" }),
					ultros.Input({ value = fpair and fpair[2] or "" }),
				}),
			})
		end
		children[#children + 1] = HF({
			ultros.Button({ caption = "Add Filter", on_click = "add" }),
			ultros.Button({ caption = "Clear Filters", on_click = "clear" }),
		})
		return ultros.gather("filters", children)
	end,
	state = function()
		local filt = decode_filter(storage.debug_state.strace_filter)
		return { n = table_size(filt), filters = filt }
	end,
	message = function(me, payload)
		if payload.key == "add" then
			relm.set_state(
				me,
				function(s) return { n = s.n + 1, filters = s.filters } end
			)
			return true
		elseif payload.key == "clear" then
			relm.set_state(me, { n = 0, filters = {} })
			return true
		else
			return false
		end
	end,
})

local Strace = relm.define_element({
	name = "Cybersyn.StraceSettings",
	render = function(props, state)
		local levelv = storage.debug_state.strace_level or ""
		local alevelv = storage.debug_state.strace_always_level or ""
		local wlstate = not not storage.debug_state.strace_whitelist
		return VF({
			relm.Gather({}, {
				ultros.Labeled({ caption = "Level" }, {
					ultros.tag("level", ultros.Input({ numeric = true, value = levelv })),
				}),
				ultros.Labeled({ caption = "Always Level" }, {
					ultros.tag(
						"always_level",
						ultros.Input({ numeric = true, value = alevelv })
					),
				}),
				ultros.tag(
					"whitelist",
					ultros.Checkbox({ caption = "Whitelist", value = wlstate })
				),
				StraceFilters(),
				HF({
					ultros.Button({ caption = "Set", on_click = "set" }),
					ultros.Button({ caption = "Test", on_click = "test" }),
				}),
			}),
		})
	end,
	message = function(me, payload)
		if payload.key == "set" then
			local _, result = relm.query_broadcast(me, { key = "value" })
			if not result then return true end
			local args = {
				tonumber(result.level),
				tonumber(result.always_level),
				encode_filter(result.filters),
				result.whitelist,
			}
			_G.cs2.debug.set_strace(table.unpack(args))
			strace(strace_lib.INFO, "setting strace", args)
			return true
		elseif payload.key == "test" then
			strace(strace_lib.INFO, "message", "plain message")
			strace(strace_lib.WARN, "key1", "value1", "message", "k1v1")
			strace(
				strace_lib.ERROR,
				"key1",
				"value1",
				"key2",
				"value2",
				"message",
				"k1v1k2v2"
			)
			return true
		else
			return false
		end
	end,
})

--------------------------------------------------------------------------------
-- Threads
--------------------------------------------------------------------------------

local thread_renderers = {
	state = default_renderer,
	submode = default_renderer,
	workload = default_renderer,
	paused = default_renderer,
	workload_counter = default_renderer,
	prov_index = default_renderer,
	req_index = default_renderer,
	train_index = default_renderer,
	providers = rt(rt_array(rt_fields("node_id", rt_val), DISPLAYED_LIMIT)),
	requesters = rt(rt_array(rt_fields("node_id", rt_val), DISPLAYED_LIMIT)),
}

local ThreadDebugger = relm.define_element({
	name = "Cybersyn.Debugger.Threads",
	render = function(props, state)
		relm.use_effect(1, function(me) relm.msg(me, { key = "update" }) end)
		relm_helpers.use_event("cs2.debug_thread_step")
		local me = relm.use_handle()

		---@cast state table
		local dropdown_options = tlib.t_map_a(state.threads, function(thr, id)
			local name = thr and thr.friendly_name
			return {
				key = id,
				caption = (name and name ~= "") and name or ("Unnamed thread " .. id),
			}
		end)

		local thr = thread.get_thread(state.selected_thread) or EMPTY

		return VF({
			ultros.Dropdown({
				value = state.selected_thread,
				options = dropdown_options,
				on_change = function(_, selected)
					relm_helpers.assign_state(me, { selected_thread = selected })
				end,
			}),
			ultros.ShallowSection({ caption = "Thread state" }, {
				relm_table.render_table(2, thr, thread_renderers, nil, {
					style = "relm_table_white_lines",
					draw_vertical_lines = true,
					draw_horizontal_lines = true,
				}),
			}),
			HF({
				ultros.Button({ caption = "Pause", on_click = "pause" }),
				ultros.Button({ caption = "Start", on_click = "start" }),
				ultros.Button({ caption = "Step", on_click = "step" }),
			}),
		})
	end,
	message = function(me, payload, props, state)
		---@cast state table
		local key = payload.key
		if key == "update" then
			local threads = thread.debug_get_threads()
			relm_helpers.assign_state(me, { threads = threads })
			return true
		elseif key == "cs2.debug_thread_step" then
			relm.paint(me)
			return true
		elseif key == "pause" then
			local thr = thread.get_thread(state.selected_thread)
			if thr then thr.paused = true end
			return true
		elseif key == "start" then
			local thr = thread.get_thread(state.selected_thread)
			if thr then thr.paused = false end
			return true
		elseif key == "step" then
			local thr = thread.get_thread(state.selected_thread)
			if thr then thr.stepped = true end
			return true
		else
			return false
		end
	end,
	state = function() return { threads = {} } end,
})

--------------------------------------------------------------------------------
-- Debugger GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "Cybersyn.Debugger",
	render = function(props, state)
		return ultros.WindowFrame({
			caption = "Cybersyn Debugger",
		}, {
			Pr({ type = "tabbed-pane" }, {
				Pr({ type = "tab", caption = "Threads" }),
				ThreadDebugger(),
			}),
		})
	end,
	message = function(_, payload, props)
		if payload.key == "close" then
			relm.root_destroy(props.root_id)
			return true
		end
		return false
	end,
})

---@param player_index int
function _G.cs2.debug.open_debugger(player_index)
	local player = game.get_player(player_index)
	if not player then return end
	local screen = player.gui.screen
	-- Close existing one
	if screen["CS2Debugger"] then
		relm.root_destroy(relm.get_root_id(screen["CS2Debugger"]))
	end
	-- Reopen
	relm.root_create(screen, "CS2Debugger", "Cybersyn.Debugger", {})
end
