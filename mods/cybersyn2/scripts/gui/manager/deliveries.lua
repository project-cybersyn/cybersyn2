local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local mgr_elts = require("scripts.gui.manager.elements")
local base_elts = require("scripts.gui.elements")
local tlib = require("lib.core.table")
local siglib = require("lib.core.signal")

local Pr = relm.Primitive
local key_to_signal = siglib.key_to_signal
local pairs = pairs
local next = next

local lib = {}

local Delivery = relm.define(
	"Manager.DeliveryDelivery",
	---@param props { delivery: Cybersyn.Delivery }
	function(props)
		local delivery = props.delivery
		local delivery_id = delivery and delivery.id
		local veh = cs2.get_vehicle(delivery.vehicle_id, true)

		relm_util.use_event_handler(
			"cs2.delivery_state_changed",
			function(me, _, changed_delivery)
				if changed_delivery.id == delivery_id then relm.paint(me) end
			end
		)

		local veh_entity = veh and veh:get_entity()
		local from_node = delivery and storage.nodes[delivery.from_id]
		local to_node = delivery and storage.nodes[delivery.to_id]
		local from_entity = from_node and from_node:get_entity()
		local to_entity = to_node and to_node:get_entity()
		local state_label = delivery
				and cs2.delivery_state_short_names[delivery.state]
			or ""
		local network = (delivery and delivery.networks) and next(delivery.networks)

		return Pr({
			type = "frame",
			style = "relm_table_row_frame",
		}, {
			ultros.Label(delivery_id or "", { width = 72 }),
			base_elts.MinimapButton({
				entity = veh_entity,
				width = 48,
				height = 48,
			}),
			base_elts.MinimapButton({
				entity = from_entity,
				width = 48,
				height = 48,
			}),
			base_elts.MinimapButton({
				entity = to_entity,
				width = 48,
				height = 48,
			}),
			ultros.BoldLabel(state_label, { width = 96 }),
			Pr({
				type = "choose-elem-button",
				elem_type = "signal",
				style = "relm_slot_button_default",
				elem_value = network and { type = "virtual", name = network },
				enabled = false,
			}),
			base_elts.Manifest({
				delivery = delivery,
				column_count = 12,
				limit = 12,
				height = 40,
			}),
		})
	end
)

local Deliveries = relm.define(
	"Manager.DeliveryDeliveries",
	---@param props { deliveries: Cybersyn.Delivery[] }
	function(props)
		return tlib.map(
			props.deliveries,
			function(delivery) return Delivery({ delivery = delivery }) end
		)
	end
)

lib.DeliveriesTab = relm.define(
	"Manager.DeliveriesTab",
	---@param props {active_topology_id: integer?, set_active_topology_id: fun(id: integer?), cargo: SignalID?, set_cargo: fun(cargo: SignalID?), network: string?, set_network: fun(network: string?)}
	function(props)
		local active_topology_id, set_active_topology_id =
			props.active_topology_id, props.set_active_topology_id
		local cargo, set_cargo = props.cargo, props.set_cargo
		local network, set_network = props.network, props.set_network

		---@param delivery Cybersyn.Delivery
		local function delivery_filter(delivery)
			if delivery.topology_id ~= active_topology_id then return false end
			if network then
				local delivery_networks = delivery.networks
				if (not delivery_networks) or not delivery_networks[network] then
					return false
				end
			end
			if not cargo then return true end
			local manifest = delivery.manifest
			local cargo_name = cargo.name
			if manifest[cargo_name] then return true end

			-- XXX: this is ugly AF
			for key in pairs(manifest) do
				local sig = key_to_signal(key)
				if sig and sig.name == cargo_name then return true end
			end
			return false
		end

		relm_util.use_event_handler(
			"cs2.delivery_created",
			function(me, _, delivery)
				if delivery_filter(delivery) then relm.paint(me) end
			end
		)

		local deliveries, n_deliveries = tlib.t_map_an(
			storage.deliveries,
			function(delivery)
				if delivery_filter(delivery) then return delivery end
			end
		)
		table.sort(deliveries, function(a, b) return a.id > b.id end)
		local limit = 30
		local n_pages = math.ceil(n_deliveries / limit)
		local page, set_page = relm.use_state(1)
		local clamped_page = math.max(1, math.min(page, n_pages))
		local deliveries_page = tlib.slice(
			deliveries,
			(clamped_page - 1) * limit + 1,
			clamped_page * limit
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
			Pr({
				type = "frame",
				style = "subheader_frame",
				direction = "horizontal",
				horizontally_stretchable = true,
			}, {
				ultros.Label("ID", { style = "subheader_caption_label", width = 72 }),
				ultros.Label("Veh", { style = "subheader_caption_label", width = 48 }),
				ultros.Label("Prov", { style = "subheader_caption_label", width = 48 }),
				ultros.Label("Req", { style = "subheader_caption_label", width = 48 }),
				ultros.Label(
					"Status",
					{ style = "subheader_caption_label", width = 96 }
				),
				ultros.Label("Net", { style = "subheader_caption_label", width = 40 }),
				ultros.Label("Manifest", { style = "subheader_caption_label" }),
			}),
			Pr({
				type = "scroll-pane",
				style = "relm_table_scroll_pane",
				vertical_scroll_policy = "always",
				horizontal_scroll_policy = "never",
			}, {
				Deliveries({
					deliveries = deliveries_page,
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
