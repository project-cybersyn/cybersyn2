local strace_lib = require("__cybersyn2__.lib.core.strace")
local relm = require("__cybersyn2__.lib.core.relm.relm")
local relm_helpers = require("__cybersyn2__.lib.core.relm.util")
local ultros = require("__cybersyn2__.lib.core.relm.ultros")
local tlib = require("__cybersyn2__.lib.core.table")
local mgr = _G.mgr

local strace = strace_lib.strace
local Pr = relm.Primitive
local empty = tlib.empty

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

local renderers = {
	id = function() end,
	inventory = function(_, counts)
		return ultros.BoldLabel("inventory"), render_counts(counts)
	end,
	inflow = function(_, counts)
		return ultros.BoldLabel("inflow"), render_counts(counts)
	end,
	outflow = function(_, counts)
		return ultros.BoldLabel("outflow"), render_counts(counts)
	end,
	orders = function(_, orders)
		local res = {}
		for _, order in pairs(orders) do
			res[#res + 1] = ultros.RtBoldLabel(
				"order [color="
					.. (order.combinator_input or "default")
					.. "]"
					.. order.combinator_id
					.. "[/color]"
			)
			res[#res + 1] = render_order(order)
		end
		return table.unpack(res)
	end,
}

local function default_renderer(k, v)
	return ultros.BoldLabel(k), ultros.RtMultilineLabel(strace_lib.stringify(v))
end

relm.define_element({
	name = "InspectorItem.Inventory",
	render = function(props, state)
		relm.use_effect(1, function(me) relm.msg(me, { payload = "update" }) end)
		relm_helpers.use_timer(120, "update")
		local result = ((state or empty).data or empty)[1] or empty

		local children = {}
		for k, v in pairs(result) do
			local renderer = renderers[k] or default_renderer
			tlib.append(children, renderer(k, v))
		end
		return relm.Primitive({
			type = "table",
			horizontally_stretchable = true,
			column_count = 2,
		}, children)
	end,
	message = function(me, payload, props)
		if payload.key == "update" then
			local result = remote.call(
				"cybersyn2",
				"query",
				{ type = "inventories", ids = { props.inventory_id } }
			)
			relm.set_state(me, result)
			return true
		end
		return false
	end,
})
