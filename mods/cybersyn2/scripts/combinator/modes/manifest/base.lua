--------------------------------------------------------------------------------
-- Manifest output combinator
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local signal_lib = require("__cybersyn2__.lib.signal")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local Delivery = _G.cs2.Delivery
local signal_to_key = signal_lib.signal_to_key
local key_to_signal = signal_lib.key_to_signal
local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Manifest",
	render = function(props) return nil end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Manifest.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel(
				"Outputs the [font=default-bold]manifest[/font] of the parked train in the form of item and fluid signals. The manifest reflects the desired cargo of the train, and may be different than the actual cargo."
			),
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = "Signal Outputs",
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
			}, {
				ultros.BoldLabel("Signal"),
				ultros.BoldLabel("Value"),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel(
					"Cargo and quantities of this train's manifest. [font=default-bold]Positive[/font] signals indicate items the train is dropping off. [font=default-bold]Negative[/font] signals indicate items the train is picking up."
				),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "manifest",
	localized_string = "cybersyn2-combinator-modes.manifest",
	settings_element = "CombinatorGui.Mode.Manifest",
	help_element = "CombinatorGui.Mode.Manifest.Help",
	is_output = true,
})

--------------------------------------------------------------------------------
-- Impl
--------------------------------------------------------------------------------

---@param manifest SignalCounts
---@param sign number
local function create_manifest_outputs(manifest, sign)
	local outputs = {}
	for key, count in pairs(manifest) do
		local signal = key_to_signal(key)
		if signal then
			outputs[#outputs + 1] = {
				signal = signal,
				constant = count * sign,
				copy_count_from_input = false,
			}
		end
	end
	return outputs
end

cs2.on_train_arrived(function(train, cstrain, stop)
	if not cstrain or not stop or not cstrain.delivery_id then return end
	local delivery = Delivery.get(cstrain.delivery_id) --[[@as Cybersyn.TrainDelivery?]]
	if not delivery then return end
	if delivery.from_id == stop.id then
		-- If this is the pickup stop for the delivery, output negative manifest
		local outputs = create_manifest_outputs(delivery.manifest, -1)
		local combs = stop:get_associated_combinators(
			function(comb) return comb.mode == "manifest" end
		)
		for _, comb in pairs(combs) do
			comb:direct_write_outputs(outputs)
		end
	elseif delivery.to_id == stop.id then
		-- If this is the dropoff stop for the delivery, output positive manifest
		local outputs = create_manifest_outputs(delivery.manifest, 1)
		local combs = stop:get_associated_combinators(
			function(comb) return comb.mode == "manifest" end
		)
		for _, comb in pairs(combs) do
			comb:direct_write_outputs(outputs)
		end
	else
		return
	end
end)

cs2.on_train_departed(function(train, cstrain, stop)
	if not cstrain or not stop then return end
	-- On train departure, clear all manifest combs.
	local combs = stop:get_associated_combinators(
		function(c) return c.mode == "manifest" end
	)
	local empty = {}
	for _, comb in pairs(combs) do
		comb:direct_write_outputs(empty)
	end
end)
