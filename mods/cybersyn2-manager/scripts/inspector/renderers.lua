local strace_lib = require("__cybersyn2__.lib.core.strace")
local relm = require("__cybersyn2__.lib.core.relm.relm")
local relm_helpers = require("__cybersyn2__.lib.core.relm.util")
local relm_table = require("__cybersyn2__.lib.core.relm.table-renderer")
local ultros = require("__cybersyn2__.lib.core.relm.ultros")
local tlib = require("__cybersyn2__.lib.core.table")
local nlib = require("__cybersyn2__.lib.core.math.numeric")
local mgr = _G.mgr

local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local empty = tlib.empty
local default_renderer = relm_table.default_renderer
local render_table = relm_table.render_table

local lib = {}

local function on_click_focus_on(entity)
	return function(me, event)
		if entity and entity.valid then
			local player = game.get_player(event.player_index)
			if player and player.valid then player.centered_on = entity end
		end
	end
end
lib.on_click_focus_on = on_click_focus_on

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
lib.render_entity_minimap = render_entity_minimap

local function reltime_renderer(k, v)
	local t = game and game.tick or 0
	return ultros.BoldLabel(k),
		ultros.RtMultilineLabel(nlib.format_tick_relative(v, t))
end

local function render_counts(counts)
	return Pr({ type = "table", column_count = 5 }, {
		mgr.SignalCountsButtons({ signal_counts = counts }),
	})
end
lib.render_counts = render_counts

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

local function on_click_cancel_delivery(delivery_id)
	return function(me, event)
		remote.call("cybersyn2", "fail_delivery", delivery_id, "CANCELLED_BY_USER")
	end
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
		render_table(2, delivery, delivery_renderers, nil),
		ultros.Button({
			caption = "Cancel Delivery",
			on_click = on_click_cancel_delivery(delivery.id),
		}),
	})
end
lib.render_delivery = render_delivery

return lib
