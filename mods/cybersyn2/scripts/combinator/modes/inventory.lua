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
-- Settings
--------------------------------------------------------------------------------

cs2.register_combinator_setting(
	cs2.lib.make_raw_setting("inventory_mode", "inventory_mode")
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Inventory",
	render = function(props)
		return ultros.WellSection(
			{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
			{
				gui.InnerHeading({
					caption = { "cybersyn2-combinator-mode-inventory.input-modes" },
				}),
				Pr(
					{ type = "table", column_count = 2, horizontally_stretchable = true },
					{
						ultros.RadioButtons({
							value = props.combinator:read_setting(
								combinator_settings.inventory_mode
							),
							buttons = {
								{
									caption = { "cybersyn2-combinator-mode-inventory.inventory" },
									key = "inventory",
								},
								{
									caption = { "cybersyn2-combinator-mode-inventory.provides" },
									key = "provide",
								},
								{
									caption = { "cybersyn2-combinator-mode-inventory.requests" },
									key = "pull",
								},
								{
									caption = {
										"cybersyn2-combinator-mode-inventory.push-thresholds",
									},
									key = "push",
								},
								{
									caption = {
										"cybersyn2-combinator-mode-inventory.sink-thresholds",
									},
									key = "sink",
								},
								{
									caption = {
										"cybersyn2-combinator-mode-inventory.capacity",
									},
									key = "capacity",
								},
							},
							on_change = function(_, value)
								props.combinator:write_setting(
									combinator_settings.inventory_mode,
									value
								)
							end,
						}),
					}
				),
			}
		)
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
				caption = "Signal Inputs",
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
})

--------------------------------------------------------------------------------
-- Switch station between true and pseudo modes
--------------------------------------------------------------------------------

---@param stop Cybersyn.TrainStop
local function check_true_inventory_mode(stop) stop:update_inventory_mode() end

cs2.on_combinator_node_associated(function(comb, new, prev)
	if comb.mode == "inventory" then
		if new then check_true_inventory_mode(new) end
		if prev then check_true_inventory_mode(prev) end
	end
end)

cs2.on_combinator_setting_changed(function(comb, setting, new, prev)
	if
		setting == nil
		or (setting == "mode" and (new == "inventory" or prev == "inventory"))
	then
		local stop = comb:get_node("stop") --[[@as Cybersyn.TrainStop?]]
		if stop then check_true_inventory_mode(stop) end
	end
end)
