local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local stlib = require("lib.core.strace")
local events = require("lib.core.event")
local cs2 = _G.cs2
local gui = _G.cs2.gui

local strace = stlib.strace
local empty = tlib.empty
local Pr = relm.Primitive
local VF = ultros.VFlow


--------------------------------------------------------------------------------
-- Presence combinator settings.
--------------------------------------------------------------------------------

---@class (partial) Cybersyn.Combinator
---@field public get_presence_item_signal fun(): boolean
---@field public get_presence_use_carriage_index fun(): boolean
---@field public get_presence_locomotive_signal fun(self: Cybersyn.Combinator): NamedSignalID?
---@field public get_presence_cargo_signal fun(self: Cybersyn.Combinator): NamedSignalID?
---@field public get_presence_fluid_signal fun(self: Cybersyn.Combinator): NamedSignalID?
---@field public get_presence_empty_signal fun(self: Cybersyn.Combinator): NamedSignalID?

cs2.register_flag_setting("presence_item_signal", "presence_flags", 0)
cs2.register_flag_setting("presence_use_carriage_index", "presence_flags", 1)

cs2.register_raw_setting("presence_locomotive_signal", "presence_locomotive_signal")
cs2.register_raw_setting("presence_cargo_signal", "presence_cargo_signal")
cs2.register_raw_setting("presence_fluid_signal", "presence_fluid_signal")
cs2.register_raw_setting("presence_empty_signal", "presence_empty_signal")

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "presence",
	localized_string = "cybersyn2-combinator-modes.presence",
	settings_element = "CombinatorGui.Mode.Presence",
	help_element = "CombinatorGui.Mode.Presence.Help",
	is_output = true,
})

--------------------------------------------------------------------------------
-- Impl
--------------------------------------------------------------------------------

---Get the indexed position of the carriage in the train
function get_carriage_index(train, wagon)
	for index, carriage in ipairs(train.carriages) do
		if carriage == wagon then
			return index
		end
	end
	return -1
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- On train departure, clear all wagon combs.
cs2.on_train_departed(function(train, cstrain, stop)
	if not cstrain or not stop then return end
	for _, comb in cs2.iterate_combinators(stop) do
		if comb.mode == "presence" then 
            comb:direct_write_outputs(EMPTY) 
            end
	end
end)

cs2.on_train_arrived(function(train, cstrain, stop)
	if not cstrain or not stop then return end
	for _, comb in cs2.iterate_combinators(stop) do
		if comb.mode == "presence" then
			local wagon = comb:find_connected_wagon()
			local outputs = {}

			if wagon then
				local use_carriage_index = comb:get_presence_use_carriage_index()
				local output_value = 1
				if use_carriage_index then
					output_value = get_carriage_index(train, wagon)
				end

				if comb:get_presence_item_signal() then
					outputs[wagon.name] = output_value
				end

				local wagon_type = wagon.type
				if wagon_type == "cargo-wagon" then
					local cargo_signal = comb:get_presence_cargo_signal()
					if cargo_signal then
						outputs[cargo_signal.name] = output_value
					end
				elseif wagon_type == "fluid-wagon" then
					local fluid_signal = comb:get_presence_fluid_signal()
					if fluid_signal then
						outputs[fluid_signal.name] = output_value
					end
				elseif wagon_type == "locomotive" then
					local loco_signal = comb:get_presence_locomotive_signal()
					if loco_signal then
						outputs[loco_signal.name] = output_value
					end
				end
			else
				local empty_signal = comb:get_presence_empty_signal()
				if empty_signal then
					outputs[empty_signal.name] = 1
				end
			end

			comb:write_outputs(outputs, 1)
		end
	end
end)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define("CombinatorGui.Mode.Presence", function(props)
	---@type Cybersyn.Combinator
	local combinator = props.combinator
	return VF({
		ultros.WellSection({ caption = "Output Signals" }, {
			gui.Checkbox(
				"Item signal",
				"If checked, this combinator will output the item signal of the detected entity with it's carriage position as the value.",
				props.combinator,
				"presence_item_signal"
			),
			gui.Checkbox(
				"Use carriage index as signal value",
				"If checked, the output value will be the carriage index of the wagon in the train. Otherwise it will be 1.",
				props.combinator,
				"presence_use_carriage_index"
			),
			ultros.Labeled({
				caption = "Locomotive detected",
				top_margin = 6,
			}, {
				gui.VirtualSignalPicker(
					props.combinator,
					"presence_locomotive_signal",
					"Signals, if a locomotive is present."
				),
			}),
			ultros.Labeled({
				caption = "Cargo wagon detected",
				top_margin = 6,
			}, {
				gui.VirtualSignalPicker(
					props.combinator,
					"presence_cargo_signal",
					"Signals, if a cargo wagon is present."
				),
			}),
			ultros.Labeled({
				caption = "Cargo fluid detected",
				top_margin = 6,
			}, {
				gui.VirtualSignalPicker(
					props.combinator,
					"presence_fluid_signal",
					"Signals, if a fluid wagon is present."
				),
			}),
			ultros.Labeled({
				caption = "Nothing detected",
				top_margin = 6,
			}, {
				gui.VirtualSignalPicker(
					props.combinator,
					"presence_empty_signal",
					"Signals, if nothing is present."
				),
			}),
		}),
	})
	end)

relm.define(
	"CombinatorGui.Mode.Presence.Help",
	function(props)
		return VF({
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-presence.desc",
			})
		})
	end
)
