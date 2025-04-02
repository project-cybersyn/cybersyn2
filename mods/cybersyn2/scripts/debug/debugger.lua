--------------------------------------------------------------------------------
-- Debugger GUI
--------------------------------------------------------------------------------

local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local relm_helpers = require("__cybersyn2__.lib.relm-helpers")
local tlib = require("__cybersyn2__.lib.table")
local strace_lib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local strformat = string.format

local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

local function render_map_reduce(map, reduce)
	return function(k, v)
		if not v then
			return
		else
			local mapped = tlib.t_map_a(v, map)
			return ultros.BoldLabel(k), ultros.RtMultilineLabel(reduce(mapped))
		end
	end
end

local renderers = {
	topologies = render_map_reduce(
		function(x) return x.id end,
		function(y) return "{" .. table.concat(y, ", ", 1, math.min(#y, 10)) .. "}" end
	),
	nodes = render_map_reduce(
		function(x)
			if x.entity and x.entity.valid then
				return string.format("%d %s", x.id, x.entity.gps_tag)
			end
		end,
		function(y) return "{" .. table.concat(y, ", ", 1, math.min(#y, 10)) .. "}" end
	),
}

local function default_renderer(k, v)
	return ultros.BoldLabel(k), ultros.RtMultilineLabel(strace_lib.prettify(v))
end

local LoopState = relm.define_element({
	name = "LogisticsLoopDebugger.State",
	render = function(props, state)
		relm_helpers.use_event("on_debug_loop")
		local data = cs2.debug.get_logistics_thread_data()
		if not data then return nil end
		local tstate = data.state
		local children = {
			ultros.BoldLabel("state"),
			ultros.Label(tstate),
		}
		for k, v in pairs(data) do
			if k ~= "state" and k ~= "paused" and k ~= "stepped" then
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
		return VF({ width = 400 }, {
			LoopState(),
			HF({
				ultros.Button({ caption = "Pause", on_click = "pause" }),
				ultros.Button({ caption = "Step", on_click = "step" }),
			}),
		})
	end,
	message = function(me, payload, props)
		local data = cs2.debug.get_logistics_thread_data() or {}
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

local StraceFilters = relm.define_element({
	name = "Cybersyn.StraceFilters",
	render = function(props, state)
		local filters = state.filters or {}
		local children = {}
		local key, value
		for i = 1, state.n do
			key = next(filters, key)
			if key then value = filters[key] end
			children[i] = HF({}, {
				ultros.Input({ value = key }),
				ultros.Input({ value = value }),
			})
		end
		children[#children + 1] =
			ultros.Button({ caption = "Add Filter", on_click = "add" })
		return children
	end,
	state = function()
		local filt = tlib.assign({}, storage.debug_state.strace_filter)
		return { n = table_size(filt), filters = filt }
	end,
	message = function(me, payload)
		if payload.key == "add" then
			relm.set_state(me, function(s) return { n = s.n + 1 } end)
			return true
		end
		return false
	end,
})

local Strace = relm.define_element({
	name = "Cybersyn.StraceSettings",
	render = function(props, state)
		return VF({
			ultros.Labeled(
				{ caption = "Level" },
				{ ultros.Input({ numeric = true }) }
			),
			ultros.Labeled(
				{ caption = "Always Level" },
				{ ultros.Input({ numeric = true }) }
			),
			ultros.Checkbox({ caption = "Whitelist" }),
			StraceFilters(),
			ultros.Button({ caption = "Set", on_click = "set" }),
		})
	end,
	message = function(me, payload)
		if payload.key == "set" then
			local _, result = relm.query_broadcast(me, { key = "value" })
			strace(strace_lib.INFO, "message", result)
			return true
		end
		return false
	end,
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
				Pr({ type = "tab", caption = "Loop" }),
				LoopDebugger(),
				Pr({ type = "tab", caption = "strace" }),
				Strace(),
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
