---@diagnostic disable: different-requires

local strace_lib = require("__cybersyn2__.lib.core.strace")
local relm = require("__cybersyn2__.lib.core.relm.relm")
local relm_helpers = require("__cybersyn2__.lib.core.relm.util")
local relm_table = require("__cybersyn2__.lib.core.relm.table-renderer")
local ultros = require("__cybersyn2__.lib.core.relm.ultros")
local tlib = require("__cybersyn2__.lib.core.table")
local renderers = require("scripts.inspector.renderers")
local mgr = _G.mgr

local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local empty = tlib.EMPTY
local default_renderer = relm_table.default_renderer
local render_table = relm_table.render_table
local render_delivery = renderers.render_delivery

local stop_renderers = {}

relm.define_element({
	name = "InspectorItem.Stop",
	render = function(props, state)
		relm.use_effect(1, function(me) relm.msg(me, { payload = "update" }) end)
		relm_helpers.use_timer(120, "update")
		local stop = ((state or empty).stop or empty)
		local deliveries = ((state or empty).deliveries or empty)
		local children = {}
		tlib.append(
			children,
			render_table(2, stop, stop_renderers, default_renderer)
		)
		for _, d in pairs(deliveries) do
			tlib.append(children, render_delivery(d))
		end
		return VF({ horizontally_stretchable = true }, children)
	end,
	message = function(me, payload, props)
		if payload.key == "update" then
			local stop_res = remote.call(
				"cybersyn2",
				"query",
				{ type = "stops", ids = { props.stop_id } }
			)
			local stop = stop_res.data and stop_res.data[1]
			if not stop then return true end
			local del_res = remote.call(
				"cybersyn2",
				"query",
				{ type = "deliveries", node_id = props.stop_id }
			)
			local deliveries = del_res.data or empty
			tlib.filter_in_place(
				deliveries,
				function(d) return d.state ~= "completed" end
			)
			table.sort(
				deliveries,
				function(a, b) return a.created_tick > b.created_tick end
			)
			relm.set_state(me, { stop = stop, deliveries = deliveries })
			return true
		end
		return false
	end,
})
