--------------------------------------------------------------------------------
-- Surface inventory output combinator
--------------------------------------------------------------------------------

local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local signal_lib = require("lib.signal")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local Topology = _G.cs2.Topology
local Delivery = _G.cs2.Delivery
local signal_to_key = signal_lib.signal_to_key
local key_to_signal = signal_lib.key_to_signal
local Pr = relm.Primitive
local VF = ultros.VFlow
local empty = tlib.empty

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

---@class Cybersyn.Combinator
---@field public get_surface_inventory_mode fun(): "provided" | "pulled" | "pushed" | "sunk"

-- Which inventory data to include in the combinator output.
cs2.register_raw_setting(
	"surface_inventory_mode",
	"surface_inventory_mode",
	"provided"
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local mode_dropdown_items = {
	{
		key = "provided",
		caption = { "cybersyn2-combinator-mode-surface.provided" },
	},
	{ key = "pulled", caption = { "cybersyn2-combinator-mode-surface.pulled" } },
	{ key = "pushed", caption = { "cybersyn2-combinator-mode-surface.pushed" } },
	{ key = "sunk", caption = { "cybersyn2-combinator-mode-surface.sunk" } },
}

relm.define_element({
	name = "CombinatorGui.Mode.Surface",
	render = function(props)
		return VF({
			ultros.WellSection(
				{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
				{
					ultros.Labeled({
						caption = { "cybersyn2-combinator-mode-surface.output-mode" },
						top_margin = 6,
					}, {
						gui.Dropdown(
							nil,
							props.combinator,
							"surface_inventory_mode",
							mode_dropdown_items
						),
					}),
				}
			),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Surface.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-surface.desc" }),
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = { "cybersyn2-combinator-modes-labels.signal-outputs" },
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
			}, {
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.signal" }),
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.value" }),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-surface.output-signals",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

-- cs2.register_combinator_mode({
-- 	name = "surface",
-- 	localized_string = "cybersyn2-combinator-modes.surface",
-- 	settings_element = "CombinatorGui.Mode.Surface",
-- 	help_element = "CombinatorGui.Mode.Surface.Help",
-- 	is_output = true,
-- 	is_input = false,
-- })
