--------------------------------------------------------------------------------
-- Relm elements for displaying inventory in the train GUI.
--------------------------------------------------------------------------------

local events = require("lib.core.event")
local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local pos_lib = require("lib.core.math.pos")
local gui_elements = require("scripts.gui.elements")
local siglib = require("lib.signal")
local types = require("lib.types")
local cs2 = _G.cs2

local HF = ultros.HFlow
local VF = ultros.VFlow
local Pr = relm.Primitive
local OrderStatus = types.OrderStatus
local OrderStatusColor = types.OrderStatusColor
local OrderStatusDescription = types.OrderStatusDescription
local EMPTY = tlib.EMPTY

local lib = {}

local NodeOrder = relm.define("NodeGui.Order", function(props)
	local order = props.order --[[@as Cybersyn.Order]]

	-- Skip orders not delivered to this node (shared inv)
	if order.node_id ~= props.node.id then return end

	-- Skip orders not doing anything
	local is_requester = order:is_requester()
	local is_provider = order:is_provider()
	if (not is_requester) and not is_provider then return end

	local thresh = order.thresh_in or EMPTY

	local buttons = {}
	buttons[#buttons + 1] = {
		signal = siglib.key_to_signal("cybersyn2-priority"),
		count = order.priority,
	}
	for k, v in pairs(order.networks or EMPTY) do
		buttons[#buttons + 1] = {
			signal = siglib.key_to_signal(k),
			count = v,
		}
	end
	for k, v in pairs(order.provides or EMPTY) do
		buttons[#buttons + 1] = {
			signal = siglib.key_to_signal(k),
			count = v,
			button_style = "relm_slot_button_green",
		}
	end
	for k, v in pairs(order.requests or EMPTY) do
		local item_threshold = thresh[k]
		buttons[#buttons + 1] = {
			signal = siglib.key_to_signal(k),
			count = v,
			upper = item_threshold,
			button_style = "relm_slot_button_yellow",
		}
	end
	for k, v in pairs(order.requested_fluids or EMPTY) do
		local item_threshold = thresh[k]
		buttons[#buttons + 1] = {
			signal = siglib.key_to_signal(k),
			count = v,
			upper = item_threshold,
			button_style = "relm_slot_button_yellow",
		}
	end

	return Pr({
		type = "frame",
		style = "relm_raised_frame",
		direction = "vertical",
		width = 336,
	}, {
		Pr({
			type = "frame",
			style = "relm_frame_slot_buttons_shallow",
			direction = "horizontal",
			width = 320,
		}, {
			ultros.SlotButtonTable({
				column_count = 8,
				buttons = buttons,
				uppers = true,
				style = "slot_table",
			}),
		}),
		ultros.CallIf(is_requester, function()
			local label = OrderStatusDescription[order.status or ""] or "No status" --[[@as LocalisedString]]

			-- Special case for no_Vehicle status: extended description
			if order.status == OrderStatus.no_vehicle then
				local info = order.status_info or tlib.EMPTY
				local n = info.n or 0
				local busy = info.busy or 0
				local capacity = info.capacity or 0
				local allowlist = info.allowlist or 0
				label = {
					"",
					label,
					" ",
					busy,
					"/",
					n,
					" busy, ",
					capacity,
					"/",
					n,
					" capacity, ",
					allowlist,
					"/",
					n,
					" not allowed",
				}
			end

			return HF({ vertical_align = "center" }, {
				ultros.Indicator(OrderStatusColor[order.status or ""] or "black"),
				ultros.Label(label),
			})
		end),
	})
end)

local NodeFlows = relm.define("NodeGui.Flows", function(props)
	local inflow = props.inflow or EMPTY
	local outflow = props.outflow or EMPTY
	local buttons = {}
	for k, v in pairs(inflow) do
		buttons[#buttons + 1] = {
			signal = siglib.key_to_signal(k),
			count = v,
			button_style = "relm_slot_button_green",
		}
	end
	for k, v in pairs(outflow) do
		buttons[#buttons + 1] = {
			signal = siglib.key_to_signal(k),
			count = v,
			button_style = "relm_slot_button_yellow",
		}
	end
	if #buttons == 0 then return nil end
	return Pr({
		type = "frame",
		style = "relm_frame_slot_buttons_shallow",
		direction = "horizontal",
		width = 320,
		left_margin = 6,
	}, {
		ultros.SlotButtonTable({
			column_count = 8,
			buttons = buttons,
			style = "slot_table",
		}),
	})
end)

local NodeInv = relm.define("NodeGui.Inv", function(props)
	local inventory = props.inventory
	local buttons = {}
	for k, v in pairs(inventory or EMPTY) do
		buttons[#buttons + 1] = {
			signal = siglib.key_to_signal(k),
			count = v,
		}
	end
	if #buttons == 0 then return nil end

	return Pr({
		type = "frame",
		style = "relm_frame_slot_buttons_shallow",
		direction = "horizontal",
		width = 320,
		left_margin = 6,
	}, {
		ultros.SlotButtonTable({
			column_count = 8,
			buttons = buttons,
			style = "slot_table",
		}),
	})
end)

local NodeInventory = relm.define("NodeGui.Inventory", function(props)
	local node = props.node --[[@as Cybersyn.Node]]
	local topology_id = node:get_topology_id()
	local tick = game and game.tick or 0
	local render_tick, set_render_tick = relm.use_state(tick)

	relm_util.use_event_handler(
		"cs2.logistics_thread_init",
		function(me, _, _topology_id)
			if _topology_id ~= topology_id then return end
			local _tick = game and game.tick or 0
			if _tick - render_tick > 60 then set_render_tick(_tick) end
		end
	)

	local inventory = node:get_inventory()
	if not inventory then
		return Pr({ type = "label", caption = "No inventory" })
	end

	return {
		ultros.WellSection(
			{ caption = "Inventory" },
			NodeInv({ node = node, inventory = inventory.inventory })
		),
		ultros.WellSection(
			{ caption = "Orders" },
			tlib.map(
				inventory.orders,
				function(order) return NodeOrder({ node = node, order = order }) end
			)
		),
		ultros.WellSection(
			{ caption = "Flows" },
			NodeFlows({
				node = node,
				inflow = inventory.inflow,
				outflow = inventory.outflow,
			})
		),
	}
end)

lib.NodeInventory = NodeInventory

return lib
