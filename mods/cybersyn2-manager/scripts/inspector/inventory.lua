local strace_lib = require("__cybersyn2__.lib.core.strace")
local relm = require("__cybersyn2__.lib.core.relm.relm")
local relm_helpers = require("__cybersyn2__.lib.core.relm.util")
local relm_table = require("__cybersyn2__.lib.core.relm.table-renderer")
local ultros = require("__cybersyn2__.lib.core.relm.ultros")
local tlib = require("__cybersyn2__.lib.core.table")
local mgr = _G.mgr

local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local empty = tlib.empty
local default_renderer = relm_table.default_renderer

local function render_counts(counts)
	return Pr({ type = "table", column_count = 5 }, {
		mgr.SignalCountsButtons({ signal_counts = counts }),
	})
end

---@param order Cybersyn.Order
local function render_order(order)
	return Pr({
		type = "table",
		column_count = 5,
	}, {
		mgr.SignalCountsButtons({
			signal_counts = order.provides,
			button_style = "flib_slot_button_blue",
		}),
		mgr.SignalCountsButtons({
			signal_counts = order.requests,
			button_style = "flib_slot_button_yellow",
		}),
		mgr.SignalCountsButtons({
			signal_counts = order.networks,
			button_style = "flib_slot_button_grey",
		}),
		mgr.SignalCountsButtons({
			signal_counts = { ["cybersyn2-priority"] = order.priority or 0 },
			button_style = "flib_slot_button_grey",
		}),
		mgr.SignalCountsButtons({
			signal_counts = order.thresholds_in,
			button_style = "flib_slot_button_cyan",
		}),
	})
end

local inventory_renderers = {
	id = function() end,
	created_for_node_id = default_renderer,
	inventory = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("inventory"), render_counts(counts)
		end
	end,
	inflow = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("inflow"), render_counts(counts)
		end
	end,
	outflow = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("outflow"), render_counts(counts)
		end
	end,
}

local order_renderers = {
	item_mode = default_renderer,
	request_stacks = default_renderer,
	quality_spread = default_renderer,
	priority = default_renderer,
	busy_value = default_renderer,
	network_matching_mode = default_renderer,
	stacked_requests = default_renderer,
	force_away = default_renderer,
	needs = default_renderer,
	provides = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("provides"), render_counts(counts)
		end
	end,
	requests = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("requests"), render_counts(counts)
		end
	end,
	requested_fluids = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("requested_fluids"), render_counts(counts)
		end
	end,
	networks = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("networks"), render_counts(counts)
		end
	end,
	thresh_in = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("thresh_in"), render_counts(counts)
		end
	end,
	thresh_depletion = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("thresh_depletion"), render_counts(counts)
		end
	end,
	thresh_explicit = function(_, counts)
		if next(counts) then
			return ultros.BoldLabel("thresh_explicit"), render_counts(counts)
		end
	end,
	thresh_depletion_fraction = default_renderer,
	thresh_fullness_fraction = default_renderer,
	thresh_min_slots = default_renderer,
	thresh_min_fluid = default_renderer,
}

relm.define_element({
	name = "InspectorItem.Inventory",
	render = function(props, state)
		relm.use_effect(1, function(me) relm.msg(me, { payload = "update" }) end)
		relm_helpers.use_timer(120, "update")
		local result = state or empty --[[@as table]]

		-- local children = {}
		-- for k, v in pairs(result) do
		-- 	local renderer = renderers[k] or default_renderer
		-- 	tlib.append(children, renderer(k, v))
		-- end
		-- return relm.Primitive({
		-- 	type = "table",
		-- 	horizontally_stretchable = true,
		-- 	column_count = 2,
		-- }, children)

		local children = {
			ultros.ShallowSection({ caption = "General" }, {
				relm_table.render_table(2, result, inventory_renderers, nil, {
					style = "relm_table_white_lines",
					draw_vertical_lines = true,
					draw_horizontal_lines = true,
				}),
			}),
		}

		for _, order in pairs(result.orders or empty) do
			local caption = string.format(
				"[color=%s]Order %d[/color]",
				order.combinator_input or "default",
				order.combinator_id
			)

			children[#children + 1] = ultros.ShallowSection({ caption = caption }, {
				relm_table.render_table(2, order, order_renderers, nil, {
					style = "relm_table_white_lines",
					draw_vertical_lines = true,
					draw_horizontal_lines = true,
				}),
			})
		end

		return VF(children)
	end,
	message = function(me, payload, props)
		if payload.key == "update" then
			local result = remote.call(
				"cybersyn2",
				"query",
				{ type = "inventories", ids = { props.inventory_id } }
			)
			local new_state = ((result or empty).data or empty)[1] or empty
			relm.set_state(me, new_state)
			return true
		end
		return false
	end,
})
