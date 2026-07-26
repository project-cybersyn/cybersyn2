local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local elts = require("scripts.gui.manager.elements")
local base_elts = require("scripts.gui.elements")
local tlib = require("lib.core.table")
local fnlib = require("lib.core.function")

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

local lib = {}

--------------------------------------------------------------------------------
-- Layouts
--------------------------------------------------------------------------------

local Layout = relm.define(
	"Manager.VehicleLayout",
	---@param props {layout_id: integer, vehicles: Cybersyn.Vehicle[], layout: Cybersyn.TrainLayout?, selected: boolean?, set_selected_layout_id: fun(id: integer?): void}
	function(props)
		local layout = props.layout
		local layout_id = props.layout_id
		local selected = props.selected
		local set_selected_layout_id = props.set_selected_layout_id or fnlib.noop

		local function repaint_if_layout(me, _, veh)
			local veh_layout_id = veh.layout_id
			if
				(veh_layout_id == layout_id)
				or (layout_id == 0 and not veh_layout_id)
			then
				relm.paint(me)
			end
		end

		relm_util.use_event_handler("cs2.vehicle_delivery_set", repaint_if_layout)
		relm_util.use_event_handler(
			"cs2.vehicle_delivery_cleared",
			repaint_if_layout
		)

		local layout_label = "(Unknown layout)"
		if layout then
			layout_label = cs2.encode_item_names(layout.carriage_names)
		end
		local free_counts = tlib.count_partition(props.vehicles, function(veh)
			if not veh.delivery_id then
				return 1
			else
				return 2
			end
		end)
		local free_count = free_counts[1] or 0
		local total_count = free_count + (free_counts[2] or 0)
		local progress = free_count / math.max(total_count, 1)

		return Pr({
			type = "frame",
			style = selected and "relm_table_row_frame_selected"
				or "relm_table_row_frame",
			direction = "vertical",
			listen = true,
			message_handler = ultros.handle_gui_events(
				defines.events.on_gui_click,
				function() set_selected_layout_id(layout_id) end
			),
		}, {
			ultros.RtLabel(layout_label, { listen = true }),
			HF({ vertical_align = "center", listen = true }, {
				ultros.Label({ "", free_count, "/", total_count }, { listen = true }),
				Pr({
					type = "progressbar",
					value = progress,
					horizontally_stretchable = true,
					listen = true,
				}),
			}),
		})
	end
)

local Layouts = relm.define(
	"Manager.VehicleLayouts",
	---@param props {layouts: table<integer, Cybersyn.Vehicle[]>, selected_layout_id: integer?, set_selected_layout_id: fun(id: integer?): void}
	function(props)
		return tlib.t_map_a(
			props.layouts,
			function(vehicles, id)
				return Layout({
					layout_id = id,
					vehicles = vehicles,
					layout = storage.train_layouts[id],
					selected = (id == props.selected_layout_id),
					set_selected_layout_id = props.set_selected_layout_id,
				})
			end
		)
	end
)

local VehicleLeftPane = relm.define(
	"Manager.VehicleLeftPane",
	---@param props {layouts: table<integer, Cybersyn.Vehicle[]>, selected_layout_id: integer?, set_selected_layout_id: fun(id: integer?): void}
	function(props)
		return Pr({
			type = "frame",
			style = "deep_frame_in_shallow_frame",
			direction = "vertical",
			vertically_stretchable = true,
			width = 250,
		}, {
			Pr({
				type = "frame",
				style = "subheader_frame",
				direction = "horizontal",
				horizontally_stretchable = true,
			}, {
				ultros.Label("Layout", { style = "subheader_caption_label" }),
			}),
			Pr({
				type = "scroll-pane",
				style = "relm_table_scroll_pane",
				vertical_scroll_policy = "always",
				horizontal_scroll_policy = "never",
			}, {
				Layouts({
					layouts = props.layouts,
					selected_layout_id = props.selected_layout_id,
					set_selected_layout_id = props.set_selected_layout_id,
				}),
			}),
		})
	end
)

--------------------------------------------------------------------------------
-- Vehs
--------------------------------------------------------------------------------

local Vehicle = relm.define("Manager.VehicleVehicle", function(props)
	local veh = props.vehicle
	local delivery = veh.delivery_id and storage.deliveries[veh.delivery_id]
	local delivery_caption = delivery and ("Delivery " .. delivery.id) or "None"

	local veh_entity = veh:get_entity()
	local from_node = delivery and storage.nodes[delivery.from_id]
	local to_node = delivery and storage.nodes[delivery.to_id]
	local from_entity = from_node and from_node:get_entity()
	local to_entity = to_node and to_node:get_entity()
	local state_label = delivery
			and cs2.delivery_state_short_names[delivery.state]
		or "[color=green]Avail[/color]"

	return Pr({
		type = "frame",
		style = "relm_table_row_frame",
	}, {
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
		base_elts.Manifest({
			delivery = delivery,
			column_count = 12,
			limit = 12,
			height = 40,
		}),
	})
end)

local Vehicles = relm.define(
	"Manager.VehicleVehicles",
	---@param props {vehicles: Cybersyn.Vehicle[]}
	function(props)
		local vehicles = props.vehicles

		return tlib.t_map_a(
			vehicles,
			function(veh) return Vehicle({ vehicle = veh }) end
		)
	end
)

local VehicleRightPane = relm.define(
	"Manager.VehicleRightPane",
	---@param props {vehicles: Cybersyn.Vehicle[], topology_id: integer?, layout_id: integer?}
	function(props)
		local vehicles = props.vehicles
		local layout_id = props.layout_id
		local topology_id = props.topology_id

		local function repaint_if_layout(me, _, veh)
			local veh_layout_id = veh.layout_id
			local veh_topology_id = veh:get_topology_id()
			if veh_topology_id ~= topology_id then return end
			if
				(veh_layout_id == layout_id)
				or (layout_id == 0 and not veh_layout_id)
			then
				relm.paint(me)
			end
		end

		relm_util.use_event_handler("cs2.vehicle_delivery_set", repaint_if_layout)
		relm_util.use_event_handler(
			"cs2.vehicle_delivery_cleared",
			repaint_if_layout
		)

		local limit = 30
		local n_vehicles = #vehicles
		table.sort(vehicles, function(a, b)
			if a.delivery_id and not b.delivery_id then return true end
			if b.delivery_id and not a.delivery_id then return false end
			return a.id < b.id
		end)
		local n_pages = math.ceil(n_vehicles / limit)
		local page, set_page = relm.use_state(1)
		local vehicles_page =
			tlib.slice(vehicles, (page - 1) * limit + 1, page * limit)

		return Pr({
			type = "frame",
			style = "deep_frame_in_shallow_frame",
			direction = "vertical",
			vertically_stretchable = true,
			width = 720,
		}, {
			Pr({
				type = "frame",
				style = "subheader_frame",
				direction = "horizontal",
				horizontally_stretchable = true,
			}, {
				ultros.Label("Veh", { style = "subheader_caption_label", width = 48 }),
				ultros.Label("Prov", { style = "subheader_caption_label", width = 48 }),
				ultros.Label("Req", { style = "subheader_caption_label", width = 48 }),
				ultros.Label(
					"Status",
					{ style = "subheader_caption_label", width = 96 }
				),
				ultros.Label("Manifest", { style = "subheader_caption_label" }),
			}),
			Pr({
				type = "scroll-pane",
				style = "relm_table_scroll_pane",
				vertical_scroll_policy = "always",
				horizontal_scroll_policy = "never",
			}, {
				Vehicles({
					vehicles = vehicles_page,
				}),
			}),
			elts.Pager({
				page = page,
				set_page = set_page,
				n_pages = n_pages,
			}),
		})
	end
)

--------------------------------------------------------------------------------
-- Vehicles tab
--------------------------------------------------------------------------------

local VehicleDisplayPanes = relm.define(
	"Manager.VehicleDisplayPanes",
	---@param props {topology_id: integer?}
	function(props)
		local selected_layout_id, set_selected_layout_id =
			relm.use_state(nil --[[@as integer?]])

		local topology_id = props.topology_id

		-- Repaint when a vehicle is added or removed from the topology
		relm_util.use_event_handler(
			"cs2.vehicle_topology_changed",
			function(me, _, veh, prev_top_id)
				if not topology_id then return end
				if
					veh:get_topology_id() == topology_id or prev_top_id == topology_id
				then
					relm.paint(me)
				end
			end
		)

		local topology_veh = tlib.t_map_a(storage.vehicles, function(veh)
			if veh:get_topology_id() == topology_id then return veh end
		end)

		local veh_layouts = tlib.partition(topology_veh, function(veh)
			if veh.type == "train" then
				---@cast veh Cybersyn.Train
				return veh.layout_id --[[@as integer]]
			else
				return 0 --[[@as integer]]
			end
		end)

		return HF(
			{ horizontally_stretchable = true, vertically_stretchable = true },
			{
				VehicleLeftPane({
					layouts = veh_layouts,
					selected_layout_id = selected_layout_id,
					set_selected_layout_id = set_selected_layout_id,
				}),
				VehicleRightPane({
					topology_id = topology_id,
					layout_id = selected_layout_id,
					vehicles = veh_layouts[selected_layout_id or -1] or {},
				}),
			}
		)
	end
)

lib.VehiclesTab = relm.define(
	"Manager.VehiclesTab",
	---@param props {active_topology_id: integer?, set_active_topology_id: fun(id: integer?)}
	function(props)
		return {
			Pr({
				type = "frame",
				style = "inside_shallow_frame_with_padding",
				horizontally_stretchable = true,
				vertically_stretchable = false,
				vertical_align = "center",
			}, {
				elts.TopologySelector({
					topology_id = props.active_topology_id,
					set_topology_id = props.set_active_topology_id,
				}),
			}),
			VehicleDisplayPanes({ topology_id = props.active_topology_id }),
		}
	end
)

return lib
