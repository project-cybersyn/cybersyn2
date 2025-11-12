--------------------------------------------------------------------------------
-- Station combinator.
--------------------------------------------------------------------------------

local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
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
---@field public get_primary_wire fun(self: Cybersyn.Combinator): string
---@field public get_provide_subset fun(self: Cybersyn.Combinator): boolean
---@field public get_disable_auto_thresholds fun(self: Cybersyn.Combinator): boolean
---@field public get_auto_threshold_percent fun(self: Cybersyn.Combinator): number
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

-- Name of the network virtual signal.
cs2.register_raw_setting("network_signal", "network")
-- Whether the station should provide, request, or both.
-- 0 = p/r, 1 = p, 2 = r
cs2.register_raw_setting("pr", "pr")
-- Whether the station should interpret minimum delivery sizes as stacks or items.
cs2.register_flag_setting("use_stack_thresholds", "station_flags", 0)
-- Which input wire the primary/true inventory input is on.
cs2.register_raw_setting("primary_wire", "primary_wire", "red")
-- Whether the station's primary order should provide the whole inventory or a subset.
cs2.register_flag_setting("provide_subset", "station_flags", 4)
-- Whether to disable auto thresholds
cs2.register_flag_setting("disable_auto_thresholds", "station_flags", 5)
-- Auto threshold percentage
cs2.register_raw_setting("auto_threshold_percent", "auto_threshold_percent")

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
cs2.register_flag_setting("ignore_secondary_thresholds", "station_flags", 3)

-- Topology
cs2.register_raw_setting("topology_signal", "topology_signal")

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local wire_dropdown_items = {
	{ key = "red", caption = { "cybersyn2-combinator-mode-station.red" } },
	{ key = "green", caption = { "cybersyn2-combinator-mode-station.green" } },
}

relm.define_element({
	name = "CombinatorGui.Mode.Station",
	render = function(props)
		local pr = props.combinator:get_pr()
		local is_provider = pr == 1 or pr == 0
		local is_requester = pr == 2 or pr == 0
		local is_provide_only = pr == 1
		local is_request_only = pr == 2
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
						caption = { "cybersyn2-combinator-mode-station.network" },
						top_margin = 6,
					}, {
						gui.NetworkSignalPicker(
							props.combinator,
							"network_signal",
							{ "cybersyn2-combinator-mode-station.network-tooltip" }
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
					gui.InnerHeading({
						caption = "Flags",
					}),
					gui.Checkbox(
						"Use stack thresholds",
						"If checked, all item delivery thresholds will be interpreted as stacks of items. If unchecked, all item delivery thresholds will be interpreted as individual items.",
						props.combinator,
						"use_stack_thresholds"
					),
					gui.Checkbox(
						{ "cybersyn2-combinator-mode-station.provide-all" },
						{ "cybersyn2-combinator-mode-station.provide-all-tooltip" },
						props.combinator,
						"provide_subset",
						true,
						is_requester,
						false
					),
					HF({ vertical_align = "center" }, {
						gui.Checkbox(
							{ "cybersyn2-combinator-mode-station.auto-mds" },
							{ "cybersyn2-combinator-mode-station.auto-mds-tooltip" },
							props.combinator,
							"disable_auto_thresholds",
							true,
							is_provide_only
						),
						HF({ horizontally_stretchable = true }, {}),
						gui.Input({
							tooltip = {
								"cybersyn2-combinator-mode-station.auto-mds-percent-tooltip",
							},
							combinator = props.combinator,
							setting = "auto_threshold_percent",
							displayed_default_value = math.floor(
								mod_settings.default_auto_threshold_fraction * 100
							),
							width = 75,
							numeric = true,
							allow_decimal = false,
							allow_negative = false,
							enabled = not is_provide_only,
						}),
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
				}
			),
			ultros.WellFold({ caption = "Departure Conditions" }, {
				ultros.Labeled(
					{ caption = "Signal: Allow departure", top_margin = 6 },
					{
						gui.AnySignalPicker(props.combinator, "allow_departure_signal"),
					}
				),
				ultros.Labeled(
					{ caption = "Signal: Force departure", top_margin = 6 },
					{
						gui.AnySignalPicker(props.combinator, "force_departure_signal"),
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
			ultros.WellFold({
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
				-- XXX: temp disabled until new algorithm
				-- gui.Checkbox(
				-- 	"Ignore minimum delivery size for secondary items",
				-- 	"If checked, when loading secondary items onto an outgoing train, this station will ignore minimum delivery sizes for those items. This can result in multiple items being more efficiently packed onto trains.",
				-- 	props.combinator,
				-- 	"ignore_secondary_thresholds"
				-- ),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Help
--------------------------------------------------------------------------------

local MainWireHelp = relm.define_element({
	name = "CombinatorGui.Mode.Station.Help.MainWire",
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
					wire_color = primary_wire,
				}),
				OrderWireHelp({
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
			or setting == nil
		then
			local node = combinator:get_node()
			if node then node:rebuild_inventory() end
		end
	end
)
