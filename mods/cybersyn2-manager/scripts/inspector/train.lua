local strace_lib = require("__cybersyn2__.lib.core.strace")
local relm = require("__cybersyn2__.lib.core.relm.relm")
local relm_helpers = require("__cybersyn2__.lib.core.relm.util")
local relm_table = require("__cybersyn2__.lib.core.relm.table-renderer")
local ultros = require("__cybersyn2__.lib.core.relm.ultros")
local tlib = require("__cybersyn2__.lib.core.table")
local nlib = require("__cybersyn2__.lib.core.math.numeric")
local renderers = require("scripts.inspector.renderers")
local mgr = _G.mgr

local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local empty = tlib.empty
local default_renderer = relm_table.default_renderer
local render_table = relm_table.render_table
local render_entity_minimap = renderers.render_entity_minimap
local render_delivery = renderers.render_delivery

local vehicle_renderers = {
	stock = render_entity_minimap,
	stopped_at = render_entity_minimap,
}

relm.define_element({
	name = "InspectorItem.Train",
	render = function(props, state)
		relm.use_effect(1, function(me) relm.msg(me, { payload = "update" }) end)
		relm_helpers.use_timer(120, "update")
		local vehicle = ((state or empty).veh or empty)
		local deliveries = ((state or empty).deliveries or empty)

		local children = {}
		tlib.append(
			children,
			render_table(2, vehicle, vehicle_renderers, default_renderer)
		)
		for _, d in pairs(deliveries) do
			tlib.append(children, render_delivery(d))
		end
		return VF({ horizontally_stretchable = true }, children)
	end,
	message = function(me, payload, props)
		if payload.key == "update" then
			local veh_q = remote.call(
				"cybersyn2",
				"query",
				{ type = "vehicles", luatrain_ids = { props.train_id } }
			)
			local veh = veh_q.data[1]
			if not veh then return true end
			local del_q = remote.call("cybersyn2", "query", {
				type = "deliveries",
				vehicle_id = veh.id,
			})
			local dels = del_q.data
			table.sort(
				dels,
				function(a, b) return a.created_tick > b.created_tick end
			)
			relm.set_state(me, { veh = veh, deliveries = dels })
			return true
		end
		return false
	end,
})
