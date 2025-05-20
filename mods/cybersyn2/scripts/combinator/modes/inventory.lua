--------------------------------------------------------------------------------
-- Inventory input combinator
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui
local Inventory = _G.cs2.Inventory
local TrueInventory = _G.cs2.TrueInventory

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local strace = stlib.strace

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Inventory",
	render = function(props)
		-- No settings
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Inventory.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-inventory.desc",
			}),
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = { "cybersyn2-combinator-modes-labels.signal-inputs" },
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
			}, {
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.signal" }),
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.effect" }),
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
