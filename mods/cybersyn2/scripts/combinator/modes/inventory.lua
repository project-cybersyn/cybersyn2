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
local strace = stlib.strace

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Inventory",
	render = function(props) return nil end,
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
				ultros.RtLgLabel("[virtual-signal=cybersyn2-inventory]"),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-inventory-control.input-signal-id",
				}),
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
local function check_true_inventory_mode(stop)
	local combs = stop:get_associated_combinators(
		function(c) return c.mode == "inventory" end
	)
	if #combs == 0 then
		-- Return stop to its internal pseudoinventory
		stop:set_inventory(stop.created_inventory_id)
		-- Destroy created true inventory
		if stop.true_inventory_id then
			local inv = Inventory.get(stop.true_inventory_id)
			if inv then
				strace(
					stlib.DEBUG,
					"cs2",
					"inventory",
					"message",
					"Destroying true inventory at stop",
					stop.id
				)
				inv:destroy()
			end
			stop.true_inventory_id = nil
		end
	else
		-- Create true inventory if needed
		if not stop.true_inventory_id then
			strace(
				stlib.DEBUG,
				"cs2",
				"inventory",
				"message",
				"Creating true inventory at stop",
				stop.id
			)
			local inv = TrueInventory.new()
			stop.true_inventory_id = inv.id
		end
		-- Swap stop to true inventory
		stop:set_inventory(stop.true_inventory_id)
	end
end

-- Detect per wagon on assoc
cs2.on_combinator_node_associated(function(comb, new, prev)
	if comb.mode == "inventory" then
		if new then check_true_inventory_mode(new) end
		if prev then check_true_inventory_mode(prev) end
	end
end)

-- Detect per wagon on mode change
cs2.on_combinator_setting_changed(function(comb, setting, new, prev)
	if
		setting == nil
		or (setting == "mode" and (new == "inventory" or prev == "inventory"))
	then
		local stop = comb:get_node("stop") --[[@as Cybersyn.TrainStop?]]
		if stop then check_true_inventory_mode(stop) end
	end
end)
