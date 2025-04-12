--------------------------------------------------------------------------------
-- Wagon manifest, formerly known as "wagon control"
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
	name = "CombinatorGui.Mode.WagonManifest",
	render = function(props) return nil end,
})

relm.define_element({
	name = "CombinatorGui.Mode.WagonManifest.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-wagon.desc" }),
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
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.signal" }),
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.value" }),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-wagon.input-signals",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "wagon",
	localized_string = "cybersyn2-combinator-modes.wagon",
	settings_element = "CombinatorGui.Mode.WagonManifest",
	help_element = "CombinatorGui.Mode.WagonManifest.Help",
	is_output = true,
})

--------------------------------------------------------------------------------
-- Impl
--------------------------------------------------------------------------------

---@param stop Cybersyn.TrainStop
local function check_per_wagon_mode(stop)
	local combs = stop:get_associated_combinators(
		function(c) return c.mode == "wagon" end
	)
	if #combs == 0 and stop.per_wagon_mode then
		stop.per_wagon_mode = nil
		cs2.raise_node_data_changed(stop)
	elseif #combs > 0 and not stop.per_wagon_mode then
		stop.per_wagon_mode = true
		cs2.raise_node_data_changed(stop)
	end
end

cs2.on_combinator_node_associated(function(comb, new, prev)
	if comb.mode == "wagon" then
		if new then check_per_wagon_mode(new) end
		if prev then check_per_wagon_mode(prev) end
	end
end)

cs2.on_combinator_setting_changed(function(comb, setting, new, prev)
	if
		setting == nil
		or (setting == "mode" and (new == "wagon" or prev == "wagon"))
	then
		local stop = comb:get_node("stop") --[[@as Cybersyn.TrainStop?]]
		if stop then check_per_wagon_mode(stop) end
	end
end)
