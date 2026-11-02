--------------------------------------------------------------------------------
-- Station combinator.
--------------------------------------------------------------------------------

local relm = require("lib.core.relm.relm")
local relm_util = require("lib.core.relm.util")
local ultros = require("lib.core.relm.ultros")
local cs2 = _G.cs2
local gui = _G.cs2.gui
local mod_settings = _G.cs2.mod_settings

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local If = ultros.If

--------------------------------------------------------------------------------
-- Station combinator settings.
--------------------------------------------------------------------------------

---@class (partial) Cybersyn.Combinator
---@field public get_network_signal fun(self: Cybersyn.Combinator): string
---@field public get_pr fun(self: Cybersyn.Combinator): number
---@field public get_use_stack_thresholds fun(self: Cybersyn.Combinator): boolean
---@field public get_primary_wire fun(self: Cybersyn.Combinator): "red"|"green"
---@field public get_provide_subset fun(self: Cybersyn.Combinator): boolean
---@field public get_disable_auto_thresholds fun(self: Cybersyn.Combinator): boolean
---@field public get_auto_threshold_percent fun(self: Cybersyn.Combinator): number
---@field public get_train_fullness_percent fun(self: Cybersyn.Combinator): number
---@field public get_allow_departure_signal fun(self: Cybersyn.Combinator): SignalID?
---@field public get_force_departure_signal fun(self: Cybersyn.Combinator): SignalID?
---@field public get_inactivity_mode fun(self: Cybersyn.Combinator): number
---@field public get_inactivity_timeout fun(self: Cybersyn.Combinator): uint
---@field public get_disable_cargo_condition fun(self: Cybersyn.Combinator): boolean
---@field public get_spillover fun(self: Cybersyn.Combinator): uint
---@field public get_reserved_slots fun(self: Cybersyn.Combinator): uint
---@field public get_reserved_capacity fun(self: Cybersyn.Combinator): uint
---@field public get_produce_single_item fun(self: Cybersyn.Combinator): boolean
---@field public get_ignore_secondary_thresholds fun(self: Cybersyn.Combinator): boolean
---@field public get_topology_signal fun(self: Cybersyn.Combinator): NamedSignalID?
---@field public get_signal_depletion_percentage fun(self: Cybersyn.Combinator): NamedSignalID?
---@field public get_signal_fullness_percentage fun(self: Cybersyn.Combinator): NamedSignalID?
---@field public get_signal_reserved_slots fun(self: Cybersyn.Combinator): NamedSignalID?
---@field public get_signal_reserved_fluid fun(self: Cybersyn.Combinator): NamedSignalID?
---@field public get_signal_spillover fun(self: Cybersyn.Combinator): NamedSignalID?
---@field public get_shared_inventory_independent_orders fun(self: Cybersyn.Combinator): boolean
---@field public get_fullness_when_providing fun(self: Cybersyn.Combinator): boolean
---@field public get_allow_strict fun(): boolean
---@field public get_allow_bidi fun(): boolean
---@field public get_allow_all fun(): boolean

-- Name of the network virtual signal.
cs2.register_raw_setting("network_signal", "network")
-- Whether the station should provide, request, or both.
-- 0 = p/r, 1 = p, 2 = r
cs2.register_raw_setting("pr", "pr")
-- DEPRECATED: Whether the station should interpret minimum delivery sizes as stacks or items.
cs2.register_flag_setting("use_stack_thresholds", "station_flags", 0)
-- Which input wire the primary/true inventory input is on.
cs2.register_raw_setting("primary_wire", "primary_wire", "red")
-- Whether the station's primary order should provide the whole inventory or a subset.
cs2.register_flag_setting("provide_subset", "station_flags", 4)
-- DEPRECATED: auto thresholds cannot be disabled anymore.
cs2.register_flag_setting("disable_auto_thresholds", "station_flags", 5)

-- Departure conditions
cs2.register_raw_setting("allow_departure_signal", "allow_departure_signal")
cs2.register_raw_setting("force_departure_signal", "force_departure_signal")
-- How to apply inactivity timeouts
-- 0 = disabled, 1 = after delivery, 2 = force out
cs2.register_raw_setting("inactivity_mode", "inactivity_mode")
cs2.register_raw_setting("inactivity_timeout", "inactivity_timeout")
cs2.register_flag_setting("disable_cargo_condition", "station_flags", 1)

-- Multi-item related
cs2.register_raw_setting("spillover", "spillover")
cs2.register_raw_setting("reserved_slots", "reserved_slots")
cs2.register_raw_setting("reserved_capacity", "reserved_capacity")
cs2.register_flag_setting("produce_single_item", "station_flags", 2)
-- DEPRECATED: new logistics algorithm doesn't need this
cs2.register_flag_setting("ignore_secondary_thresholds", "station_flags", 3)

-- Topology
cs2.register_raw_setting("topology_signal", "topology_signal")

-- Config input signals
cs2.register_raw_setting(
	"signal_depletion_percentage",
	"signal_depletion_percentage"
)
cs2.register_raw_setting(
	"signal_fullness_percentage",
	"signal_fullness_percentage"
)
cs2.register_raw_setting("signal_reserved_slots", "signal_reserved_slots")
cs2.register_raw_setting("signal_reserved_fluid", "signal_reserved_fluid")
cs2.register_raw_setting("signal_spillover", "signal_spillover")

-- Thresholds
cs2.register_raw_setting("auto_threshold_percent", "auto_threshold_percent")
cs2.register_raw_setting("train_fullness_percent", "train_fullness_percent")
cs2.register_flag_setting("fullness_when_providing", "station_flags", 7)

-- Shared inventory
cs2.register_flag_setting(
	"shared_inventory_independent_orders",
	"station_flags",
	6
)

-- Allowlist
cs2.register_flag_setting("allow_strict", "allow_flags", 0)
cs2.register_flag_setting("allow_bidi", "allow_flags", 1)
cs2.register_flag_setting("allow_all", "allow_flags", 2)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local STATUS_SHARED_NONE = {
	color = "red",
	caption = { "cybersyn2-combinator-mode-station.status-shared-none" },
}
local STATUS_SHARED_MASTER = {
	color = "green",
	caption = { "cybersyn2-combinator-mode-station.status-shared-master" },
}
local STATUS_SHARED_SLAVE = {
	color = "green",
	caption = { "cybersyn2-combinator-mode-station.status-shared-slave" },
}

local function get_status_props(is_master, is_slave)
	if is_master then
		return STATUS_SHARED_MASTER
	elseif is_slave then
		return STATUS_SHARED_SLAVE
	else
		return STATUS_SHARED_NONE
	end
end

local wire_dropdown_items = {
	{ key = "red", caption = { "cybersyn2-combinator-mode-station.red" } },
	{ key = "green", caption = { "cybersyn2-combinator-mode-station.green" } },
}

relm.define_element({
	name = "CombinatorGui.Mode.Station",
	render = function(props)
		---@type Cybersyn.Combinator
		local combinator = props.combinator
		local stop = cs2.get_stop(combinator and combinator.node_id or 0)
		local is_shared, is_master, is_slave = false, nil, nil
		if stop then
			if stop.shared_inventory_master then
				is_shared = true
				is_slave = true
			elseif stop.is_master then
				is_shared = true
				is_master = true
			end
		end
		relm_util.use_event("cs2.train_stop_shared_inventory_link")
		relm_util.use_event("cs2.train_stop_shared_inventory_unlink")

		local pr = combinator:get_pr()
		local is_provider = pr == 1 or pr == 0
		local is_requester = pr == 2 or pr == 0
		local is_provide_only = pr == 1
		local is_request_only = pr == 2

		local primary_wire = combinator:get_primary_wire()
		local secondary_wire = primary_wire == "red" and "green" or "red"

		local allow_all = combinator:get_allow_all()

		return VF({
			ultros.WellSection(
				{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
				{
					ultros.Labeled({
						caption = { "cybersyn2-combinator-mode-station.cargo" },
						top_margin = 6,
					}, {
						gui.Switch(
							{ "cybersyn2-combinator-mode-station.cargo-switch-tooltip" },
							true,
							{ "cybersyn2-combinator-mode-station.cargo-outbound-only" },
							{ "cybersyn2-combinator-mode-station.cargo-inbound-only" },
							props.combinator,
							"pr"
						),
					}),
					ultros.Labeled({
						caption = {
							"cybersyn2-combinator-mode-station.primary-input-wire",
						},
						top_margin = 6,
					}, {
						gui.Dropdown(
							nil,
							props.combinator,
							"primary_wire",
							wire_dropdown_items
						),
					}),
					ultros.Labeled({
						caption = { "cybersyn2-combinator-mode-station.topology" },
						top_margin = 6,
					}, {
						gui.VirtualSignalPicker(
							props.combinator,
							"topology_signal",
							{ "cybersyn2-combinator-mode-station.topology-tooltip" }
						),
					}),
					gui.InnerHeading({
						caption = { "cybersyn2-combinator-modes-labels.flags" },
					}),
					gui.Checkbox(
						{ "cybersyn2-combinator-mode-station.provide-all" },
						{ "cybersyn2-combinator-mode-station.provide-all-tooltip" },
						props.combinator,
						"provide_subset",
						true,
						is_requester,
						false
					),
				}
			),
			gui.OrderWireSettings({
				combinator = combinator,
				wire_color = secondary_wire,
				arity = "primary",
				is_request_only = is_request_only,
				is_provide_only = is_provide_only,
			}),
			ultros.WellSection({
				caption = { "cybersyn2-combinator-mode-station.thresholds" },
			}, {
				ultros.If(
					is_requester,
					ultros.Labeled({
						caption = { "cybersyn2-combinator-mode-station.depletion-threshold" },
						top_margin = 6,
					}, {
						gui.Input({
							tooltip = {
								"cybersyn2-combinator-mode-station.depletion-threshold-tooltip",
							},
							combinator = combinator,
							setting = "auto_threshold_percent",
							displayed_default_value = math.floor(
								mod_settings.default_auto_threshold_fraction * 100
							),
							width = 75,
							numeric = true,
							allow_decimal = false,
							allow_negative = false,
						}),
					})
				),
				ultros.Labeled(
					{
						caption = { "cybersyn2-combinator-mode-station.fullness-threshold" },
						top_margin = 6,
					},
					{
						gui.Input({
							tooltip = {
								"cybersyn2-combinator-mode-station.fullness-threshold-tooltip",
							},
							combinator = combinator,
							setting = "train_fullness_percent",
							displayed_default_value = math.floor(
								mod_settings.default_train_fullness_fraction * 100
							),
							width = 75,
							numeric = true,
							allow_decimal = false,
							allow_negative = false,
						}),
					}
				),
				ultros.If(
					is_provider,
					gui.Checkbox(
						{ "cybersyn2-combinator-mode-station.fullness-when-providing" },
						{
							"cybersyn2-combinator-mode-station.fullness-when-providing-tooltip",
						},
						props.combinator,
						"fullness_when_providing"
					)
				),
			}),
			ultros.WellSection({
				caption = { "cybersyn2-combinator-mode-station.allow-list" },
			}, {
				gui.Checkbox(
					{ "cybersyn2-combinator-mode-station.allow-strict" },
					{ "cybersyn2-combinator-mode-station.allow-strict-tooltip" },
					props.combinator,
					"allow_strict",
					false,
					allow_all,
					false
				),
				gui.Checkbox(
					{ "cybersyn2-combinator-mode-station.allow-bidi" },
					{ "cybersyn2-combinator-mode-station.allow-bidi-tooltip" },
					props.combinator,
					"allow_bidi",
					false,
					allow_all,
					false
				),
				gui.Checkbox(
					{ "cybersyn2-combinator-mode-station.allow-all" },
					{ "cybersyn2-combinator-mode-station.allow-all-tooltip" },
					props.combinator,
					"allow_all"
				),
			}),
			ultros.WellSection({
				caption = { "cybersyn2-combinator-mode-station.departure-conditions" },
			}, {
				ultros.Labeled({
					caption = { "cybersyn2-combinator-mode-station.allow-departure-signal" },
					top_margin = 6,
				}, {
					gui.AnySignalPicker(
						props.combinator,
						"allow_departure_signal",
						{
							"cybersyn2-combinator-mode-station.allow-departure-signal-tooltip",
						}
					),
				}),
				ultros.Labeled({
					caption = { "cybersyn2-combinator-mode-station.force-departure-signal" },
					top_margin = 6,
				}, {
					gui.AnySignalPicker(
						props.combinator,
						"force_departure_signal",
						{
							"cybersyn2-combinator-mode-station.force-departure-signal-tooltip",
						}
					),
				}),
				ultros.Labeled({
					caption = { "cybersyn2-combinator-mode-station.inactivity-mode" },
					top_margin = 6,
				}, {
					gui.Switch(
						{ "cybersyn2-combinator-mode-station.inactivity-mode-tooltip" },
						true,
						{ "cybersyn2-combinator-mode-station.inactivity-mode-after-delivery" },
						{ "cybersyn2-combinator-mode-station.inactivity-mode-force-out" },
						props.combinator,
						"inactivity_mode"
					),
				}),
				ultros.Labeled(
					{
						caption = { "cybersyn2-combinator-mode-station.inactivity-timeout" },
						top_margin = 6,
					},
					{
						gui.Input({
							combinator = props.combinator,
							setting = "inactivity_timeout",
							width = 75,
							numeric = true,
							allow_decimal = false,
							allow_negative = false,
						}),
					}
				),
				gui.InnerHeading({
					caption = { "cybersyn2-combinator-modes-labels.flags" },
				}),
				gui.Checkbox(
					{ "cybersyn2-combinator-mode-station.cargo-condition" },
					{ "cybersyn2-combinator-mode-station.cargo-condition-tooltip" },
					props.combinator,
					"disable_cargo_condition",
					true
				),
			}),
			ultros.WellSection({
				caption = { "cybersyn2-combinator-mode-station.outbound-item-handling" },
				visible = is_provider,
			}, {
				ultros.Labeled({
					caption = { "cybersyn2-combinator-mode-station.spillover" },
					top_margin = 6,
				}, {
					gui.Input({
						tooltip = { "cybersyn2-combinator-mode-station.spillover-tooltip" },
						combinator = props.combinator,
						setting = "spillover",
						width = 75,
						numeric = true,
						allow_decimal = false,
						allow_negative = false,
					}),
				}),
				ultros.Labeled(
					{
						caption = { "cybersyn2-combinator-mode-station.reserved-slots" },
						top_margin = 6,
					},
					{
						gui.Input({
							tooltip = {
								"cybersyn2-combinator-mode-station.reserved-slots-tooltip",
							},
							combinator = props.combinator,
							setting = "reserved_slots",
							width = 75,
							numeric = true,
							allow_decimal = false,
							allow_negative = false,
						}),
					}
				),
				ultros.Labeled(
					{
						caption = { "cybersyn2-combinator-mode-station.reserved-capacity" },
						top_margin = 6,
					},
					{
						gui.Input({
							tooltip = {
								"cybersyn2-combinator-mode-station.reserved-capacity-tooltip",
							},
							combinator = props.combinator,
							setting = "reserved_capacity",
							width = 75,
							numeric = true,
							allow_decimal = false,
							allow_negative = false,
						}),
					}
				),
				gui.InnerHeading({
					caption = { "cybersyn2-combinator-modes-labels.flags" },
				}),
				gui.Checkbox(
					{ "cybersyn2-combinator-mode-station.single-item" },
					{ "cybersyn2-combinator-mode-station.single-item-tooltip" },
					props.combinator,
					"produce_single_item"
				),
			}),
			ultros.WellSection({
				caption = { "cybersyn2-combinator-mode-station.shared-inventory" },
			}, {
				gui.Status(get_status_props(is_master, is_slave)),
				ultros.If(
					is_shared,
					ultros.Button({
						caption = { "cybersyn2-combinator-mode-station.stop-sharing" },
						on_click = "stop_sharing",
					})
				),
				ultros.If(
					(not is_shared) or is_master,
					ultros.Button({
						caption = { "cybersyn2-combinator-mode-station.start-sharing" },
						on_click = "start_sharing",
					})
				),
				gui.Checkbox(
					{ "cybersyn2-combinator-mode-station.clone-orders" },
					{ "cybersyn2-combinator-mode-station.clone-orders-tooltip" },
					props.combinator,
					"shared_inventory_independent_orders",
					true,
					not is_slave
				),
			}),
			ultros.WellSection({
				caption = { "cybersyn2-combinator-mode-station.circuit-configuration" },
			}, {
				ultros.Labeled({
					caption = { "cybersyn2-combinator-mode-station.signal-depletion" },
					top_margin = 6,
				}, {
					gui.VirtualSignalPicker(
						props.combinator,
						"signal_depletion_percentage",
						{ "cybersyn2-combinator-mode-station.signal-depletion-tooltip" }
					),
				}),
				ultros.Labeled({
					caption = { "cybersyn2-combinator-mode-station.signal-fullness" },
					top_margin = 6,
				}, {
					gui.VirtualSignalPicker(
						props.combinator,
						"signal_fullness_percentage",
						{ "cybersyn2-combinator-mode-station.signal-fullness-tooltip" }
					),
				}),
				ultros.Labeled({
					caption = { "cybersyn2-combinator-mode-station.signal-reserved-slots" },
					top_margin = 6,
				}, {
					gui.VirtualSignalPicker(
						props.combinator,
						"signal_reserved_slots",
						{ "cybersyn2-combinator-mode-station.signal-reserved-slots-tooltip" }
					),
				}),
				ultros.Labeled({
					caption = { "cybersyn2-combinator-mode-station.signal-reserved-fluid" },
					top_margin = 6,
				}, {
					gui.VirtualSignalPicker(
						props.combinator,
						"signal_reserved_fluid",
						{ "cybersyn2-combinator-mode-station.signal-reserved-fluid-tooltip" }
					),
				}),
				ultros.Labeled({
					caption = { "cybersyn2-combinator-mode-station.signal-spillover" },
					top_margin = 6,
				}, {
					gui.VirtualSignalPicker(
						props.combinator,
						"signal_spillover",
						{ "cybersyn2-combinator-mode-station.signal-spillover-tooltip" }
					),
				}),
			}),
		})
	end,
	message = function(me, payload, props)
		if
			(payload.key == "cs2.train_stop_shared_inventory_link")
			or (payload.key == "cs2.train_stop_shared_inventory_unlink")
		then
			relm.paint(me)
			return true
		elseif payload.key == "stop_sharing" then
			local combinator = props.combinator
			local stop = cs2.get_stop(combinator and combinator.node_id or 0)
			if not stop then return true end
			stop:stop_sharing_inventory()
			return true
		elseif payload.key == "start_sharing" then
			local combinator = props.combinator
			local stop = cs2.get_stop(combinator and combinator.node_id or 0)
			if not stop then return true end
			relm.msg_bubble(me, { key = "close" })
			cs2.start_shared_inventory_connection(payload.event.player_index, stop.id)
			return true
		else
			return false
		end
	end,
})

--------------------------------------------------------------------------------
-- Help
--------------------------------------------------------------------------------

local MainWireHelp = relm.define_element({
	name = "CombinatorGui.Mode.Station.Help.MainWire",
	render = function(props)
		local combinator = props.combinator
		local wire_color = props.wire_color
		return {
			ultros.RtBoldLabel({
				"",
				"[color=",
				wire_color,
				"]",
				{ "cybersyn2-combinator-modes-labels.signal-inputs" },
				"[/color]",
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
			}, {
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.signal" }),
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.effect" }),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-station.true-inventory-signals",
				}),
				ultros.RtLgLabel("[virtual-signal=cybersyn2-priority]"),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-station.priority-signal",
				}),
			}),
		}
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Station.Help",
	render = function(props)
		local primary_wire = props.combinator:get_primary_wire()
		local network_signal = props.combinator:get_order_primary_network()
		local opposite_wire = primary_wire == "red" and "green" or "red"
		return VF({
			MainWireHelp({
				combinator = props.combinator,
				wire_color = primary_wire,
			}),
			cs2.gui.OrderWireHelp({
				combinator = props.combinator,
				wire_color = opposite_wire,
				network_signal = network_signal,
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Station combinator mode registration.
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "station",
	localized_string = "cybersyn2-combinator-modes.station",
	settings_element = "CombinatorGui.Mode.Station",
	help_element = "CombinatorGui.Mode.Station.Help",
	is_input = true,
	independent_input_wires = true,
})

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- Rebuild inventory on station comb reassociation
cs2.on_combinator_node_associated(function(combinator, from, to)
	if combinator.mode == "station" then
		if from then
			---@cast from Cybersyn.Node
			from:rebuild_inventory()
		end
		if to then
			---@cast to Cybersyn.Node
			to:rebuild_inventory()
		end
	end
end)

-- Rebuild inventory on critical setting changes
cs2.on_combinator_setting_changed(
	function(combinator, setting, next_value, prev_value)
		if
			(
				setting == "mode"
				and (next_value == "station" or prev_value == "station")
			)
			or setting == "primary_wire"
			or setting == "shared_inventory_independent_orders"
			or (combinator.mode == "station" and setting == nil)
		then
			local node = combinator:get_node()
			if node then node:rebuild_inventory() end
		end
	end
)

-- Apply topology on station comb reassociation
cs2.on_combinator_node_associated(function(combinator, from, to)
	if combinator.mode == "station" then
		local topology_signal = combinator:get_topology_signal()
		if from then
			---@cast from Cybersyn.Node
			from:set_topology(nil)
		end
		if to then
			---@cast to Cybersyn.Node
			if topology_signal then
				to:set_topology_by_name(topology_signal.name)
			else
				to:set_topology(nil)
			end
		end
	end
end)

-- Apply topology on critical setting changes
cs2.on_combinator_setting_changed(
	function(combinator, setting, next_value, prev_value)
		if
			(
				setting == "mode"
				and (next_value == "station" or prev_value == "station")
			)
			or setting == "topology_signal"
			or (combinator.mode == "station" and setting == nil)
		then
			local node = combinator:get_node()
			if node then
				if next_value then
					node:set_topology_by_name(next_value.name)
				else
					node:set_topology(nil)
				end
			end
		end
	end
)
