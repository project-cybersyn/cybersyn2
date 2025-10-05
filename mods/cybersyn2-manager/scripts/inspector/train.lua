local strace_lib = require("__cybersyn2__.lib.strace")
local relm = require("__cybersyn2__.lib.relm")
local relm_helpers = require("__cybersyn2__.lib.relm-helpers")
local ultros = require("__cybersyn2__.lib.ultros")
local tlib = require("__cybersyn2__.lib.table")
local nlib = require("__cybersyn2__.lib.core.math.numeric")
local mgr = _G.mgr

local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local empty = tlib.empty

local function render_counts(counts)
	return Pr({ type = "table", column_count = 5 }, {
		mgr.SignalCountsButtons({ signal_counts = counts }),
	})
end

local function on_click_focus_on(entity)
	return function(me, event)
		if entity and entity.valid then
			local player = game.get_player(event.player_index)
			if player and player.valid then player.centered_on = entity end
		end
	end
end

local function render_entity_minimap(k, v)
	return ultros.BoldLabel(k),
		ultros.Button({
			width = 125,
			height = 110,
			on_click = on_click_focus_on(v),
		}, {
			Pr({
				type = "minimap",
				width = 100,
				height = 100,
				entity = v,
			}),
		})
end

local function default_renderer(k, v)
	return ultros.BoldLabel(k), ultros.RtMultilineLabel(strace_lib.stringify(v))
end

local function reltime_renderer(k, v)
	local t = game and game.tick or 0
	return ultros.BoldLabel(k),
		ultros.RtMultilineLabel(nlib.format_tick_relative(v, t))
end

local vehicle_renderers = {
	stock = render_entity_minimap,
	stopped_at = render_entity_minimap,
}

local delivery_renderers = {
	state = default_renderer,
	created_tick = reltime_renderer,
	state_tick = reltime_renderer,
	spillover = default_renderer,
	reserved_slots = default_renderer,
	reserved_fluid_capacity = default_renderer,
	misrouted_from = default_renderer,
	misrouted_to = default_renderer,
	left_dirty = default_renderer,
}

local function render_table(tbl, renderers, default)
	renderers = renderers or empty
	local children = {}
	for k, v in pairs(tbl) do
		local renderer = renderers[k]
		if (renderer == nil) and default then renderer = default end
		if renderer then tlib.append(children, renderer(k, v)) end
	end
	return Pr({
		type = "table",
		horizontally_stretchable = true,
		column_count = 2,
	}, children)
end

local function render_delivery(delivery)
	return VF({ horizontally_stretchable = true }, {
		ultros.BoldLabel("Delivery " .. delivery.id),
		Pr({ type = "table", column_count = 2 }, {
			ultros.Button({
				width = 125,
				height = 110,
				on_click = on_click_focus_on(delivery.from_entity),
			}, {
				Pr({
					type = "minimap",
					width = 100,
					height = 100,
					entity = delivery.from_entity,
				}),
			}),
			ultros.Button({
				width = 125,
				height = 110,
				on_click = on_click_focus_on(delivery.to_entity),
			}, {
				Pr({
					type = "minimap",
					width = 100,
					height = 100,
					entity = delivery.to_entity,
				}),
			}),
		}),
		ultros.Label("Manifest"),
		render_counts(delivery.manifest),
		render_table(delivery, delivery_renderers, nil),
	})
end

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
			render_table(vehicle, vehicle_renderers, default_renderer)
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
				function(a, b) return a.created_tick < b.created_tick end
			)
			relm.set_state(me, { veh = veh, deliveries = dels })
			return true
		end
		return false
	end,
})
