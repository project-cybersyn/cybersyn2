--------------------------------------------------------------------------------
-- Inventory (Orders) input combinator
--------------------------------------------------------------------------------

local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local stlib = require("lib.core.strace")
local cs2 = _G.cs2
local gui = _G.cs2.gui
local Inventory = _G.cs2.Inventory

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local strace = stlib.strace
local strformat = string.format

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

---@class (partial) Cybersyn.Combinator
---@field public get_order_primary_stacked_requests fun(self: Cybersyn.Combinator): boolean
---@field public get_order_secondary_stacked_requests fun(self: Cybersyn.Combinator): boolean
---@field public get_order_primary_network_matching_mode fun(self: Cybersyn.Combinator): "and" | "or"
---@field public get_order_secondary_network_matching_mode fun(self: Cybersyn.Combinator): "and" | "or"
---@field public get_order_primary_network fun(self: Cybersyn.Combinator): string
---@field public get_order_secondary_network fun(self: Cybersyn.Combinator): string
---@field public get_order_primary_no_starvation fun(self: Cybersyn.Combinator): boolean
---@field public get_order_secondary_no_starvation fun(self: Cybersyn.Combinator): boolean
---@field public get_order_primary_round_to_stacks fun(self: Cybersyn.Combinator): boolean
---@field public get_order_secondary_round_to_stacks fun(self: Cybersyn.Combinator): boolean

cs2.register_flag_setting("order_primary_stacked_requests", "order_flags", 0)
cs2.register_flag_setting("order_secondary_stacked_requests", "order_flags", 1)
cs2.register_flag_setting("order_primary_no_starvation", "order_flags", 2)
cs2.register_flag_setting("order_secondary_no_starvation", "order_flags", 3)
cs2.register_flag_setting("order_primary_round_to_stacks", "order_flags", 4)
cs2.register_flag_setting("order_secondary_round_to_stacks", "order_flags", 5)

cs2.register_raw_setting(
	"order_primary_network_matching_mode",
	"order_primary_network_matching_mode",
	"or"
)
cs2.register_raw_setting(
	"order_secondary_network_matching_mode",
	"order_secondary_network_matching_mode",
	"or"
)

cs2.register_raw_setting("order_primary_network", "order_primary_network")
cs2.register_raw_setting("order_secondary_network", "order_secondary_network")

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Inventory",
	render = function(props)
		return VF({
			gui.OrderWireSettings({
				combinator = props.combinator,
				wire_color = "red",
				arity = "primary",
			}),
			gui.OrderWireSettings({
				combinator = props.combinator,
				wire_color = "green",
				arity = "secondary",
			}),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Inventory.Help",
	render = function(props)
		local combinator = props.combinator
		local red_network = combinator:get_order_primary_network()
		local green_network = combinator:get_order_secondary_network()
		return VF({
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-inventory.desc",
			}),
			gui.OrderWireHelp({ wire_color = "red", network_signal = red_network }),
			gui.OrderWireHelp({
				wire_color = "green",
				network_signal = green_network,
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "inventory",
	localized_string = "cybersyn2-combinator-modes.inventory",
	settings_element = "CombinatorGui.Mode.Inventory",
	help_element = "CombinatorGui.Mode.Inventory.Help",
	is_input = true,
	independent_input_wires = true,
})

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- When combinators are added, removed, or modechanged, if any of them are
-- inventory combinators, rebuild orders.
cs2.on_combinator_node_associated(function(combinator, from, to)
	if combinator.mode == "inventory" then
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

cs2.on_combinator_setting_changed(
	function(combinator, setting, next_value, prev_value)
		if
			(
				setting == "mode"
				and (next_value == "inventory" or prev_value == "inventory")
			) or setting == nil
		then
			local node = combinator:get_node()
			if node then node:rebuild_inventory() end
		end
	end
)
