--------------------------------------------------------------------------------
-- Node management GUI.
--------------------------------------------------------------------------------

local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local pos_lib = require("lib.core.math.pos")
local bbox_lib = require("lib.core.math.bbox")
local tlib = require("lib.core.table")
local delivery_gui = require("scripts.gui.delivery")
local inventory_gui = require("scripts.gui.inventory")
local cs2 = _G.cs2

local HF = ultros.HFlow
local VF = ultros.VFlow
local Pr = relm.Primitive

local function noop() end

--------------------------------------------------------------------------------
-- Inventory
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Delivery queue
--------------------------------------------------------------------------------

local TrainDeliveryQueue = relm.define(
	"NodeGui.TrainDeliveryQueue",
	function(props)
		local stop = props.stop --[[@as Cybersyn.TrainStop]]
		local stop_id = stop.id

		relm_util.use_event_handler(
			"cs2.node_deliveries_changed",
			function(me, _, changed_node)
				if changed_node.id == stop_id then relm.paint(me) end
			end
		)

		local deliveries = tlib.t_map_a(
			stop.deliveries,
			function(_, id) return cs2.get_delivery(id) end
		)

		return {
			ultros.WellSection({ caption = "Future Deliveries" }, {
				delivery_gui.DeliveryList({
					base_list = deliveries,
					filter = function(delivery) return true end,
					show_header = true,
				}),
			}),
		}
	end
)

local DeliveryHistory = relm.define("NodeGui.DeliveryHistory", function(props)
	local node = props.node --[[@as Cybersyn.TrainStop]]
	local node_id = node.id

	return {
		ultros.WellSection({ caption = "Delivery History" }, {
			delivery_gui.DeliveryList({
				filter = function(delivery)
					local am_prov = delivery.from_id == node_id
					local am_req = delivery.to_id == node_id
					-- Incomplete deliveries that are no longer in the provider future deliveries but should still be displayed in UX because they are enroute from.
					if am_prov and delivery:has_departed_provider() then return true end
					-- All completed or failed deliveries.
					return (am_prov or am_req) and delivery:is_in_final_state()
				end,
				show_header = true,
			}),
		}),
	}
end)

--------------------------------------------------------------------------------
-- Trainstop Debug rendering
--------------------------------------------------------------------------------

---@param stop Cybersyn.TrainStop?
local function render_stop_overlay(stop)
	if (not stop) or (not stop:is_valid()) then return {} end
	local layout = stop:get_layout()
	if not layout then return {} end
	local surface = stop.entity.surface
	local render_objs = {}

	-- BBox rect
	local l, t, r, b = bbox_lib.bbox_get(layout.bbox)
	render_objs[#render_objs + 1] = rendering.draw_rectangle({
		surface = surface,
		left_top = { l, t },
		right_bottom = { r, b },
		color = { r = 100, g = 149, b = 237 },
		width = 2,
	})

	-- Combinator associations
	for comb_id in pairs(stop.combinator_set) do
		local comb = cs2.get_combinator(comb_id)
		if comb and comb:is_real() then
			render_objs[#render_objs + 1] = rendering.draw_line({
				color = { r = 0, g = 1, b = 0.25, a = 0.25 },
				width = 2,
				surface = surface,
				from = comb.real_entity,
				to = stop.entity,
			})
		end
	end

	return render_objs
end

local StopDebugRenderer = relm.define("StopDebugRenderer", function(props)
	---@type Cybersyn.TrainStop?
	local stop = props.stop
	local stop_id = stop and stop.id

	-- Renderer
	local rk, set_rk = relm.use_state(0)
	local function render()
		set_rk(function(_rk) return _rk + 1 end)
	end
	relm.use_effect(
		rk,
		function() return render_stop_overlay(stop) end,
		function(render_objs)
			for i = 1, #render_objs do
				render_objs[i].destroy()
			end
		end
	)

	-- Drivers
	relm.use_effect(stop_id or 0, render)
	relm_util.use_event_handler(
		"cs2.stop_layout_changed",
		function(_, _, changed_stop)
			if changed_stop.id == stop_id then render() end
		end
	)
	relm_util.use_event_handler(
		"cs2.node_combinator_set_changed",
		function(_, _, changed_stop)
			if changed_stop.id == stop_id then render() end
		end
	)
end)

--------------------------------------------------------------------------------
-- Allowlist
--------------------------------------------------------------------------------

local StopAllowList = relm.define("NodeGui.StopAllowList", function(props)
	local stop = props.stop --[[@as Cybersyn.TrainStop]]
	local elts = {}

	if stop.allowed_layouts then
		for tl_id in pairs(stop.allowed_layouts) do
			local tlayout = storage.train_layouts[tl_id]
			if tlayout then
				local str = table.concat(
					tlib.map(
						(tlayout.carriage_names or tlib.EMPTY),
						function(name) return "[item=" .. name .. "]" end
					)
				)
				elts[#elts + 1] = ultros.RtLabel(str)
			end
		end
	else
		elts[#elts + 1] =
			ultros.RtLgLabel("[virtual-signal=signal-everything] All trains allowed.")
	end

	if #elts == 0 then
		elts[#elts + 1] =
			ultros.RtLgLabel("[virtual-signal=signal-alert] No trains allowed!")
	end

	relm_util.use_event_handler(
		"cs2.stop_allow_list_changed",
		function(me, _, changed_stop)
			if changed_stop.id == stop.id then relm.paint(me) end
		end
	)

	return {
		ultros.WellSection({ caption = "Allow List" }, elts),
	}
end)

--------------------------------------------------------------------------------
-- Trainstop
--------------------------------------------------------------------------------

local Stop = relm.define("NodeGui.Stop", function(props)
	local stop = props.stop --[[@as Cybersyn.TrainStop?]]

	return {
		StopDebugRenderer({
			stop = stop,
		}),
		inventory_gui.NodeInventory({
			node = stop,
		}),
		TrainDeliveryQueue({ stop = stop }),
		DeliveryHistory({
			node = stop,
		}),
		StopAllowList({
			stop = stop,
		}),
	}
end)

--------------------------------------------------------------------------------
-- Main window
--------------------------------------------------------------------------------

relm.define("NodeGui", function(props)
	---@type Cybersyn.Node?
	local node = props.node

	-- Window management
	local root_id, player_index = props.root_id, props.player_index

	local function _close_me() relm.root_destroy(root_id) end

	local pinned, set_pinned = ultros.use_pinnable()

	local close_me = ultros.use_memoized_window_position(_close_me, function()
		local player_state = cs2.get_player_state(player_index)
		return player_state and player_state.stop_gui_pos
	end, pinned and noop or function(loc)
		local player_state = cs2.get_or_create_player_state(player_index)
		player_state.stop_gui_pos = loc
	end, function(elt) elt.force_auto_center() end)

	ultros.use_close_on_gui_closed(player_index, close_me, pinned)

	-- Close window if node is destroyed
	relm_util.use_event_handler(
		"cs2.node_destroyed",
		function(me, _, destroyed_node)
			if node and destroyed_node.id == node.id then close_me() end
		end
	)

	return ultros.WindowFrame({
		caption = { "", "[virtual-signal=cybersyn2] Node ", node and node.id or "" },
		on_close = close_me,
		decoration = function()
			return ultros.PinButton({ pinned = pinned, set_pinned = set_pinned })
		end,
	}, {
		Pr({
			type = "frame",
			style = "inside_shallow_frame",
			direction = "vertical",
			width = 366,
			height = 800,
			horizontally_stretchable = false,
			vertically_stretchable = false,
		}, {
			Pr({
				type = "scroll-pane",
				direction = "vertical",
				vertically_stretchable = true,
				horizontal_scroll_policy = "never",
				vertical_scroll_policy = "always",
				extra_top_padding_when_activated = 0,
				extra_left_padding_when_activated = 0,
				extra_right_padding_when_activated = 0,
				extra_bottom_padding_when_activated = 0,
			}, {
				ultros.If(node and node.type == "stop", Stop({ stop = node })),
			}),
		}),
	})
end)

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

events.bind(
	"cs2.combinator_gui_opened",
	---@param comb Cybersyn.Combinator
	---@param player LuaPlayer
	function(comb, player)
		if comb.mode ~= "station" then return end
		local node = comb:get_node() --[[@as Cybersyn.Node?]]
		if not node then return end

		local _, elt =
			relm.root_create(player.gui.screen, nil, "NodeGui", { node = node })
	end
)
