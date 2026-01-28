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

---@class Cybersyn.Combinator
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
---@field public get_inactivity_timeout fun(self: Cybersyn.Combinator): number
---@field public get_disable_cargo_condition fun(self: Cybersyn.Combinator): boolean
---@field public get_spillover fun(self: Cybersyn.Combinator): number
---@field public get_reserved_slots fun(self: Cybersyn.Combinator): number
---@field public get_reserved_capacity fun(self: Cybersyn.Combinator): number
---@field public get_produce_single_item fun(self: Cybersyn.Combinator): boolean
---@field public get_ignore_secondary_thresholds fun(self: Cybersyn.Combinator): boolean
---@field public get_topology_signal fun(self: Cybersyn.Combinator): SignalID?
---@field public get_signal_depletion_percentage fun(self: Cybersyn.Combinator): SignalID?
---@field public get_signal_fullness_percentage fun(self: Cybersyn.Combinator): SignalID?
---@field public get_signal_reserved_slots fun(self: Cybersyn.Combinator): SignalID?
---@field public get_signal_reserved_fluid fun(self: Cybersyn.Combinator): SignalID?
---@field public get_signal_spillover fun(self: Cybersyn.Combinator): SignalID?
---@field public get_shared_inventory_independent_orders fun(self: Cybersyn.Combinator): boolean

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
cs2.register_flag_setting("apply_fullness_at_provider", "station_flags", 7)

-- Shared inventory
cs2.register_flag_setting(
	"shared_inventory_independent_orders",
	"station_flags",
	6
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local STATUS_SHARED_NONE = { color = "red", caption = "No shared inventory" }
local STATUS_SHARED_MASTER =
	{ color = "green", caption = "Sharing my inventory" }
local STATUS_SHARED_SLAVE =
	{ color = "green", caption = "Receiving shared inventory" }

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

		return VF({
			ultros.WellSection(
				{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
				{
					ultros.Labeled({ caption = "Cargo", top_margin = 6 }, {
						gui.Switch(
							"Determines whether deliveries can pick up, drop off, or both.",
							true,
							"Outbound only",
							"Inbound only",
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
						caption = "Flags",
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
			ultros.WellSection({ caption = "Thresholds" }, {
				ultros.If(
					is_requester,
					ultros.Labeled({ caption = "Depletion threshold", top_margin = 6 }, {
						gui.Input({
							tooltip = "Percentage of any requested item that must be missing before a delivery is triggered.\n\nNOTE: All thresholds are hints to the system and may not be strictly enforced.",
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
					{ caption = "Train fullness threshold", top_margin = 6 },
					{
						gui.Input({
							tooltip = "Percentage of total train cargo capacity that should be filled before a train will deliver an outstanding request.\n\nNOTE: All thresholds are hints to the system and may not be strictly enforced.",
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
						"Enforce train fullness threshold at provider",
						"If checked, this station will only provide items in quantities that meet the train fullness threshold set at this station in addition to any request thresholds that may apply.",
						props.combinator,
						"apply_fullness_at_provider"
					)
				),
			}),
			ultros.WellSection({ caption = "Departure Conditions" }, {
				ultros.Labeled(
					{ caption = "Signal: Allow departure", top_margin = 6 },
					{
						gui.AnySignalPicker(
							props.combinator,
							"allow_departure_signal",
							"Trains will only depart if this signal is present at the train stop.\n\nNOTE: The train stop must be set to send signals to the train."
						),
					}
				),
				ultros.Labeled(
					{ caption = "Signal: Force departure", top_margin = 6 },
					{
						gui.AnySignalPicker(
							props.combinator,
							"force_departure_signal",
							"If this signal is present at the train stop, the train will be forced to leave, regardless of other conditions.\n\nNOTE: The train stop must be set to send signals to the train."
						),
					}
				),
				ultros.Labeled({ caption = "Inactivity mode", top_margin = 6 }, {
					gui.Switch(
						"Determines how the inactivity timer will apply. After delivery means the train will wait the appropriate number of seconds after emptying its cargo. Force out means the train will be forced out after the appropriate number of seconds, regardless of whether it has emptied its cargo. The center position disables inactivity timeouts.",
						true,
						"After delivery",
						"Force out",
						props.combinator,
						"inactivity_mode"
					),
				}),
				ultros.Labeled(
					{ caption = "Inactivity timeout (sec)", top_margin = 6 },
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
					caption = "Flags",
				}),
				gui.Checkbox(
					"Enable cargo condition",
					"If checked, trains will receive a wait condition requiring them to pick up or drop off their cargo. If unchecked, you must manually control the train's departure using custom logic.",
					props.combinator,
					"disable_cargo_condition",
					true
				),
			}),
			ultros.WellSection({
				caption = "Outbound Item Handling",
				visible = is_provider,
			}, {
				ultros.Labeled({ caption = "Spillover", top_margin = 6 }, {
					gui.Input({
						tooltip = "A number of extra items (measured in units, not stacks) that may be loaded into each cargo wagon of an outgoing train as a result of imprecise processes such as extra inserter swings. This value is applied per-item against the capacity of the each wagon and the net inventory of the station.",
						combinator = props.combinator,
						setting = "spillover",
						width = 75,
						numeric = true,
						allow_decimal = false,
						allow_negative = false,
					}),
				}),
				ultros.Labeled(
					{ caption = "Reserved slots per cargo wagon", top_margin = 6 },
					{
						gui.Input({
							tooltip = "The number of slots that will be deducted for each cargo wagon when calculating the capacity of an outgoing train. Unlike spillover, reserve slots do not count against the net inventory of the station.",
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
					{ caption = "Reserved capacity per fluid wagon", top_margin = 6 },
					{
						gui.Input({
							tooltip = "A reserved amount of capacity to be deducted per fluid wagon. This can be used to allow pumps to clear their fluid boxes before a train departs.",
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
					caption = "Flags",
				}),
				gui.Checkbox(
					"Single item per outgoing train",
					"If checked, this station will never load multiple items onto an outgoing train, instead loading only the first matching item.",
					props.combinator,
					"produce_single_item"
				),
			}),
			ultros.WellSection({ caption = "Shared Inventory" }, {
				gui.Status(get_status_props(is_master, is_slave)),
				ultros.If(
					is_shared,
					ultros.Button({
						caption = "Stop sharing inventory",
						on_click = "stop_sharing",
					})
				),
				ultros.If(
					(not is_shared) or is_master,
					ultros.Button({
						caption = "Share this inventory with another station",
						on_click = "start_sharing",
					})
				),
				gui.Checkbox(
					"Clone orders",
					"If checked, this station will ignore its own orders and clone identical orders from the master station.",
					props.combinator,
					"shared_inventory_independent_orders",
					true,
					not is_slave
				),
			}),
			ultros.WellSection({
				caption = "Configuration via Circuit",
			}, {
				ultros.Labeled(
					{ caption = "Input signal: Depletion percentage", top_margin = 6 },
					{
						gui.VirtualSignalPicker(
							props.combinator,
							"signal_depletion_percentage",
							"The value of this signal on the primary input wire will be used as the depletion percentage for deliveries rather than the setting in the combinator."
						),
					}
				),
				ultros.Labeled({
					caption = "Input signal: Train fullness percentage",
					top_margin = 6,
				}, {
					gui.VirtualSignalPicker(
						props.combinator,
						"signal_fullness_percentage",
						"The value of this signal on the primary input wire will be used as the train fullness percentage for deliveries rather than the setting in the combinator."
					),
				}),
				ultros.Labeled({
					caption = "Input signal: Reserved slots per cargo wagon",
					top_margin = 6,
				}, {
					gui.VirtualSignalPicker(
						props.combinator,
						"signal_reserved_slots",
						"The value of this signal on the primary input wire will be used as the number of reserved slots per cargo wagon rather than the setting in the combinator."
					),
				}),
				ultros.Labeled({
					caption = "Input signal: Reserved capacity per fluid wagon",
					top_margin = 6,
				}, {
					gui.VirtualSignalPicker(
						props.combinator,
						"signal_reserved_fluid",
						"The value of this signal on the primary input wire will be used as the reserved capacity per fluid wagon rather than the setting in the combinator."
					),
				}),
				ultros.Labeled({
					caption = "Input signal: Spillover",
					top_margin = 6,
				}, {
					gui.VirtualSignalPicker(
						props.combinator,
						"signal_spillover",
						"The value of this signal on the primary input wire will be used as the spillover rather than the setting in the combinator."
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
		return {
			ultros.RtBoldLabel({
				"",
				"[color=" .. props.wire_color .. "]",
				{ "cybersyn2-combinator-modes-labels.signal" },
				"[/color]",
			}),
			ultros.RtBoldLabel({
				"cybersyn2-combinator-modes-labels.effect",
			}),
			ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-station.true-inventory-signals",
			}),
			ultros.RtLgLabel("[virtual-signal=cybersyn2-priority]"),
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-station.priority-signal",
			}),
		}
	end,
})

local OrderWireHelp = relm.define_element({
	name = "CombinatorGui.Mode.Station.Help.OrderWire",
	render = function(props)
		return {
			ultros.RtBoldLabel({
				"",
				"[color=" .. props.wire_color .. "]",
				{ "cybersyn2-combinator-modes-labels.signal" },
				"[/color]",
			}),
			ultros.RtBoldLabel({
				"cybersyn2-combinator-modes-labels.effect",
			}),
			ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-station.order-signals",
			}),
		}
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Station.Help",
	render = function(props)
		local primary_wire = props.combinator:get_primary_wire()
		local opposite_wire = primary_wire == "red" and "green" or "red"
		return VF({
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = "Signal Inputs",
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
			}, {
				MainWireHelp({
					combinator = props.combinator,
					wire_color = primary_wire,
				}),
				OrderWireHelp({
					combinator = props.combinator,
					wire_color = opposite_wire,
				}),
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
