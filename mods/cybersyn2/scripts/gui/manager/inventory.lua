local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local mgr_elts = require("scripts.gui.manager.elements")
local base_elts = require("scripts.gui.elements")
local tlib = require("lib.core.table")
local siglib = require("lib.core.signal")
local relm_slot_buttons = require("lib.core.relm.slot-buttons")
local fnlib = require("lib.core.function")
local types = require("lib.types")

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local EMPTY = tlib.empty
local pairs = pairs
local key_to_signal = siglib.key_to_signal
local next = next
local NO_PROVIDER = types.OrderStatus.no_provider
local vector_add = tlib.vector_add

local lib = {}

local Col = relm.define(
	"Manager.InvCol",
	---@param props {signals: SignalCounts, cols: uint, name_filter: string?, title: LocalisedString, set_cargo: fun(cargo: SignalID?)?, button_style?: string}
	function(props)
		local cols = props.cols or 5
		local vector = props.signals or EMPTY
		local name_filter = props.name_filter
		local title = props.title
		local set_cargo = props.set_cargo or fnlib.noop

		return VF(
			{ vertically_stretchable = true, horizontally_stretchable = false },
			{
				Pr({
					type = "frame",
					style = "subheader_frame",
					horizontally_stretchable = true,
					vertically_stretchable = false,
				}, {
					Pr({
						type = "label",
						style = "subheader_caption_label",
						caption = title,
					}),
				}),
				Pr({
					type = "scroll-pane",
					width = 40 * cols + 20,
					vertically_stretchable = true,
					vertical_scroll_policy = "always",
					horizontal_scroll_policy = "never",
				}, {
					relm_slot_buttons.SlotButtonTable({
						column_count = cols,
						style = "slot_table",
						enabled = true,
						button_style = props.button_style,
						on_click = function(button_index, signal) set_cargo(signal) end,
						get_button_iterator = function()
							return function(vec, key)
								local next_key, val = next(vec, key)
								local sig = key_to_signal(next_key)

								while
									name_filter
									and next_key
									and sig
									and sig.name ~= name_filter
								do
									next_key, val = next(vec, next_key)
									sig = key_to_signal(next_key)
								end

								return next_key, sig, val, nil, nil, nil, nil, true
							end,
								vector,
								nil
						end,
					}),
				}),
			}
		)
	end
)

local Avail = relm.define(
	"Manager.Avail",
	---@param props {orders: Cybersyn.Order[], cargo: SignalID?, set_cargo: fun(cargo: SignalID?)}
	function(props)
		local orders = props.orders
		local cargo = props.cargo
		local cols = 7

		local repaint = relm_util.use_throttled_repaint(250)
		relm_util.use_event_handler("cs2.logistics_loop_start", repaint)

		---@type SignalCounts
		local vector = {}
		for _, order in pairs(orders) do
			order:add_provides(vector)
		end

		return Col({
			signals = vector,
			cols = cols,
			set_cargo = props.set_cargo,
			name_filter = cargo and cargo.name,
			title = { "cybersyn2-manager.available" },
			button_style = "relm_slot_button_green",
		})
	end
)

local Requested = relm.define(
	"Manager.Requested",
	---@param props {orders: Cybersyn.Order[], cargo: SignalID?, set_cargo: fun(cargo: SignalID?)}
	function(props)
		local orders = props.orders
		local cargo = props.cargo
		local cols = 6

		local repaint = relm_util.use_throttled_repaint(250)
		relm_util.use_event_handler("cs2.logistics_loop_start", repaint)

		---@type SignalCounts
		local vector = {}
		for _, order in pairs(orders) do
			order:add_requests(vector)
		end

		return Col({
			signals = vector,
			cols = cols,
			set_cargo = props.set_cargo,
			name_filter = cargo and cargo.name,
			title = { "cybersyn2-manager.requested" },
		})
	end
)

local Unmatched = relm.define(
	"Manager.Unmatched",
	---@param props {orders: Cybersyn.Order[], cargo: SignalID?, set_cargo: fun(cargo: SignalID?)}
	function(props)
		local orders = props.orders
		local cargo = props.cargo
		local cols = 4

		local repaint = relm_util.use_throttled_repaint(250)
		relm_util.use_event_handler("cs2.logistics_loop_start", repaint)

		---@type SignalCounts
		local vector = {}
		for _, order in pairs(orders) do
			if order.status == NO_PROVIDER then order:add_deficits(vector) end
		end

		return Col({
			signals = vector,
			cols = cols,
			set_cargo = props.set_cargo,
			name_filter = cargo and cargo.name,
			title = { "cybersyn2-manager.unmatched" },
			button_style = "relm_slot_button_red",
		})
	end
)

local DELIV_EVENTS = { "cs2.delivery_created", "cs2.delivery_finalized" }

local InTransit = relm.define(
	"Manager.InTransit",
	---@param props {topology_id: Id?, cargo: SignalID?, network: string?, set_cargo: fun(cargo: SignalID?)}
	function(props)
		local topology_id = props.topology_id
		local cargo = props.cargo
		local network = props.network
		local cols = 5

		local revision, set_revision = relm.use_state(0)
		relm_util.use_event_handler(DELIV_EVENTS, function(me, _, delivery)
			---@cast delivery Cybersyn.Delivery
			if delivery.topology_id == topology_id then
				set_revision(function(x) return x + 1 end)
			end
		end)

		local signals = relm.use_memo({ topology_id, network, revision }, function()
			---@type SignalCounts
			local vector = {}
			for _, del in pairs(storage.deliveries) do
				if del.topology_id == topology_id and (not del:is_in_final_state()) then
					if (not network) or (del.networks or EMPTY)[network] then
						vector_add(vector, 1, del.manifest)
					end
				end
			end
			return vector
		end)

		return Col({
			signals = signals,
			cols = cols,
			set_cargo = props.set_cargo,
			name_filter = cargo and cargo.name,
			title = { "cybersyn2-manager.in-transit" },
		})
	end
)

lib.InventoryTab = relm.define(
	"Manager.InventoryTab",
	---@param props {active_topology_id: integer?, set_active_topology_id: fun(id: integer?), cargo: SignalID?, set_cargo: fun(cargo: SignalID?), network: string?, set_network: fun(network: string?)}
	function(props)
		local active_topology_id, set_active_topology_id =
			props.active_topology_id, props.set_active_topology_id
		local cargo, set_cargo = props.cargo, props.set_cargo
		local network, set_network = props.network, props.set_network

		local revision, set_revision = relm.use_state(0)
		relm_util.use_event_handler(
			"cs2.node_inventory_rebuilt",
			function(me, _, node, inventory)
				if node:get_topology_id() == active_topology_id then
					set_revision(function(x) return x + 1 end)
				end
			end
		)

		local orders_result = relm.use_memo(
			{ active_topology_id, revision },
			function()
				---@type Cybersyn.Order[]
				local orders = {}
				local n_orders = 0
				for _, node in pairs(storage.nodes) do
					if
						node:get_topology_id() == active_topology_id
						and not node.shared_inventory_master
					then
						local inv = cs2.get_inventory(node.inventory_id)
						for _, order in pairs((inv and inv.orders) or EMPTY) do
							---@cast order Cybersyn.Order
							if (not network) or order.networks[network] then
								n_orders = n_orders + 1
								orders[n_orders] = order
							end
						end
					end
				end
				return orders
			end
		)

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
			HF({
				vertically_stretchable = true,
				horizontally_stretchable = true,
				horizontal_spacing = 0,
			}, {
				Avail({ orders = orders_result, cargo = cargo, set_cargo = set_cargo }),
				Requested({
					orders = orders_result,
					cargo = cargo,
					set_cargo = set_cargo,
				}),
				InTransit({
					topology_id = active_topology_id,
					cargo = cargo,
					network = network,
					set_cargo = set_cargo,
				}),
				Unmatched({
					orders = orders_result,
					cargo = cargo,
					set_cargo = set_cargo,
				}),
			}),
		}
	end
)

return lib
