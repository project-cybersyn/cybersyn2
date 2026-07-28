local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local mgr_elts = require("scripts.gui.manager.elements")
local base_elts = require("scripts.gui.elements")
local tlib = require("lib.core.table")
local siglib = require("lib.core.signal")
local nlib = require("lib.core.math.numeric")
local types = require("lib.types")
local relm_slot_buttons = require("lib.core.relm.slot-buttons")
local fnlib = require("lib.core.function")

local noop = fnlib.noop
local Pr = relm.Primitive
local key_to_signal = siglib.key_to_signal
local pairs = pairs
local next = next
local Boolean = nlib.Boolean
local EMPTY = tlib.EMPTY
local VF = ultros.VFlow
local HF = ultros.HFlow
local OrderStatusShortDescription = types.OrderStatusShortDescription
local OrderStatusColor = types.OrderStatusColor
local OrderStatus = types.OrderStatus
local UnknownDescription = OrderStatusShortDescription[OrderStatus.unknown]

local lib = {}

local Order = relm.define(
	"Manager.NodeOrder",
	---@param props { node_id: integer, inventory: SignalCounts, order: Cybersyn.Order, set_cargo: fun(cargo: SignalID?) }
	function(props)
		local node_id = props.node_id
		local order = props.order
		local is_requester = order:is_requester()
		local status_label = is_requester
				and (OrderStatusShortDescription[order.status or OrderStatus.unknown] or UnknownDescription)
			or "Providing"
		local status_color = is_requester
				and (OrderStatusColor[order.status or OrderStatus.unknown] or "black")
			or "green"
		local set_cargo = props.set_cargo or noop
		local inventory = props.inventory
		local thresholds = order.thresh_in or EMPTY

		relm_util.use_event_handler("cs2.node_polled", function(me, _, polled_node)
			if polled_node.id == node_id then relm.paint(me) end
		end)

		local buttons = {}
		local n = 0
		n = n + 1
		buttons[n] = {
			signal = key_to_signal("cybersyn2-priority"),
			count = order.priority,
			locked = true,
		}
		for k, v in pairs(order.networks or EMPTY) do
			n = n + 1
			buttons[n] = {
				signal = key_to_signal(k),
				count = v,
				locked = true,
			}
		end
		for k, v in pairs(order.provides or EMPTY) do
			n = n + 1
			buttons[n] = {
				signal = key_to_signal(k),
				count = v,
				button_style = "relm_slot_button_green",
				locked = true,
			}
		end
		for k, v in pairs(order.requests or EMPTY) do
			local item_inv = inventory[k] or 0
			local item_threshold = thresholds[k] or 0
			local item_below_threshold = (v - item_inv) > item_threshold
			n = n + 1
			buttons[n] = {
				signal = key_to_signal(k),
				count = v,
				upper = item_inv,
				button_style = item_below_threshold and "relm_slot_button_red"
					or "relm_slot_button_default",
				locked = true,
			}
		end
		for k, v in pairs(order.requested_fluids or EMPTY) do
			local item_inv = inventory[k] or 0
			local item_threshold = thresholds[k] or 0
			local item_below_threshold = (v - item_inv) > item_threshold
			n = n + 1
			buttons[n] = {
				signal = key_to_signal(k),
				count = v,
				upper = item_inv,
				button_style = item_below_threshold and "relm_slot_button_red"
					or "relm_slot_button_default",
				locked = true,
			}
		end

		local get_button_iterator =
			relm_slot_buttons.make_button_array_iterator(buttons)

		return Pr({
			type = "frame",
			style = "relm_raised_frame",
			direction = "horizontal",
			horizontally_stretchable = true,
			vertically_stretchable = false,
		}, {
			HF({ vertical_align = "bottom", height = 28, width = 80 }, {
				ultros.Indicator(status_color),
				ultros.Label(status_label),
			}),
			relm_slot_buttons.SlotButtonTable({
				column_count = 12,
				get_button_iterator = get_button_iterator,
				style = "slot_table",
				enabled = true,
				on_click = function(button_index, signal)
					if
						signal
						and (
							signal.type == nil
							or signal.type == "item"
							or signal.type == "fluid"
						)
					then
						set_cargo(signal)
					end
				end,
			}),
		})
	end
)

local Orders = relm.define(
	"Manager.NodeOrders",
	---@param props { node: Cybersyn.Node, set_cargo: fun(cargo: SignalID?) }
	function(props)
		local node = props.node
		local inv = node:get_inventory()
		local true_inv = inv and inv.inventory or EMPTY
		local orders = inv and inv.orders or EMPTY
		local set_cargo = props.set_cargo

		return VF(
			{ horizontally_stretchable = true, vertically_stretchable = false },
			tlib.map(
				orders,
				function(order)
					return Order({
						node_id = node.id,
						order = order,
						inventory = true_inv,
						set_cargo = set_cargo,
					})
				end
			)
		)
	end
)

local Node = relm.define(
	"Manager.NodeNode",
	---@param props { node: Cybersyn.Node, set_cargo: fun(cargo: SignalID?) }
	function(props)
		local node = props.node
		local node_id = node and node.id
		local node_entity = node and node:get_entity()
		local is_slave = (node.shared_inventory_master ~= nil)
		local set_cargo = props.set_cargo

		return Pr({
			type = "frame",
			style = "relm_table_row_frame_top",
		}, {
			HF({ top_margin = 4, vertical_align = "center" }, {
				ultros.Label(node_id or "", { width = 72 }),
				base_elts.MinimapButton({
					entity = node_entity,
					width = 48,
					height = 48,
				}),
			}),
			ultros.If(is_slave, ultros.BoldLabel("Slave")),
			ultros.If(
				node and not is_slave,
				Orders({ node = node, set_cargo = set_cargo })
			),
		})
	end
)

local Nodes = relm.define(
	"Manager.NodesNodes",
	---@param props { nodes: Cybersyn.Node[], set_cargo: fun(cargo: SignalID?) }
	function(props)
		local set_cargo = props.set_cargo
		return tlib.map(
			props.nodes,
			function(node) return Node({ node = node, set_cargo = set_cargo }) end
		)
	end
)

lib.NodesTab = relm.define(
	"Manager.NodesTab",
	---@param props {active_topology_id: integer?, set_active_topology_id: fun(id: integer?), cargo: SignalID?, set_cargo: fun(cargo: SignalID?), network: string?, set_network: fun(network: string?)}
	function(props)
		local active_topology_id, set_active_topology_id =
			props.active_topology_id, props.set_active_topology_id
		local cargo, set_cargo = props.cargo, props.set_cargo
		local network, set_network = props.network, props.set_network
		local cargo_name = cargo and cargo.name

		relm_util.use_event_handler(
			"cs2.node_inventory_rebuilt",
			function(me, _, node)
				if node:get_topology_id() == active_topology_id then relm.paint(me) end
			end
		)

		---@param node Cybersyn.Node
		local function node_filter(node)
			if node:get_topology_id() ~= active_topology_id then return false end
			if (not cargo_name) and not network then return true end
			local inv = node:get_inventory()
			if not inv then return false end

			for _, order in pairs(inv.orders) do
				if network and not order:matches_network_name(network) then
					goto continue
				end
				if cargo_name and not order:matches_cargo_name(cargo_name) then
					goto continue
				end

				do
					return true
				end

				::continue::
			end

			return false
		end

		local nodes, n_nodes = tlib.t_map_an(storage.nodes, function(node)
			if node_filter(node) then return node end
		end)
		table.sort(nodes, function(a, b) return a.id > b.id end)
		local limit = 30
		local n_pages = math.ceil(n_nodes / limit)
		local page, set_page = relm.use_state(1)
		local clamped_page = math.max(1, math.min(page, n_pages))
		local nodes_page =
			tlib.slice(nodes, (clamped_page - 1) * limit + 1, clamped_page * limit)

		return {
			Pr({
				type = "frame",
				style = "inside_shallow_frame_with_padding",
				horizontally_stretchable = true,
				vertically_stretchable = false,
				top_padding = 2,
				bottom_padding = 2,
				vertical_align = "center",
			}, {
				mgr_elts.TopologySelector({
					topology_id = active_topology_id,
					set_topology_id = set_active_topology_id,
				}),
				mgr_elts.CargoSelector({ cargo = cargo, set_cargo = set_cargo }),
				mgr_elts.NetworkSelector({
					network = network,
					set_network = set_network,
				}),
			}),
			Pr({
				type = "frame",
				style = "subheader_frame",
				direction = "horizontal",
				horizontally_stretchable = true,
			}, {
				ultros.Label("ID", { style = "subheader_caption_label", width = 72 }),
				ultros.Label("Node", { style = "subheader_caption_label", width = 48 }),
				ultros.Label("Orders", { style = "subheader_caption_label" }),
			}),
			Pr({
				type = "scroll-pane",
				style = "relm_table_scroll_pane",
				vertical_scroll_policy = "always",
				horizontal_scroll_policy = "never",
			}, {
				Nodes({
					nodes = nodes_page,
					set_cargo = set_cargo,
				}),
			}),
			mgr_elts.Pager({
				page = clamped_page,
				set_page = set_page,
				n_pages = n_pages,
			}),
		}
	end
)

return lib
