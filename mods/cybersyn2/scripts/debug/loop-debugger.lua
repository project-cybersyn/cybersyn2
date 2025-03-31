--------------------------------------------------------------------------------
-- Logistics thread state debugger
--------------------------------------------------------------------------------

local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local tlib = require("__cybersyn2__.lib.table")
local log = require("__cybersyn2__.lib.logging")
local cs2 = _G.cs2
local strformat = string.format

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
	return ultros.BoldLabel(k), ultros.RtMultilineLabel(log.stringify(v))
end

local LoopState = relm.define_element({
	name = "LogisticsLoopDebugger.State",
	render = function(props, state)
		cs2.use_event("on_debug_loop")
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
	end,
})

relm.define_element({
	name = "LogisticsLoopDebugger",
	render = function(props, state)
		return ultros.WindowFrame({
			caption = "Logistics Loop Debugger",
		}, {
			VF({ width = 400 }, {
				LoopState(),
				HF({
					ultros.Button({ caption = "Pause", on_click = "pause" }),
					ultros.Button({ caption = "Step", on_click = "step" }),
				}),
			}),
		})
	end,
	message = function(me, payload, props)
		local data = cs2.debug.get_logistics_thread_data() or {}
		if payload.key == "close" then
			relm.root_destroy(props.root_id)
		elseif payload.key == "pause" then
			data.paused = not data.paused
		elseif payload.key == "step" then
			data.stepped = true
		end
	end,
})

---@param player_index int
function _G.cs2.debug.open_loop_debugger(player_index)
	local player = game.get_player(player_index)
	if not player then return end
	local screen = player.gui.screen
	if screen["LogisticsLoopDebugger"] then return end
	relm.root_create(screen, "LogisticsLoopDebugger", {}, "LogisticsLoopDebugger")
end
