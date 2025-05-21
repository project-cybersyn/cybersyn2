local strace_lib = require("__cybersyn2__.lib.strace")
local relm = require("__cybersyn2__.lib.relm")
local relm_helpers = require("__cybersyn2__.lib.relm-helpers")
local ultros = require("__cybersyn2__.lib.ultros")
local tlib = require("__cybersyn2__.lib.table")
local siglib = require("__cybersyn2__.lib.signal")
local mgr = _G.mgr

local strace = strace_lib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local empty = tlib.empty

_G.mgr.SignalCountsButtons = relm.define_element({
	name = "Cybersyn.Manager.SignalCountsButtons",
	render = function(props)
		local signal_counts = props.signal_counts or empty
		return tlib.t_map_a(signal_counts, function(qty, item)
			-- Support sets
			if qty == true then qty = 1 end
			local item_signal = siglib.key_to_signal(item)
			return Pr({
				type = "choose-elem-button",
				elem_type = "signal",
				elem_value = item_signal,
				enabled = false,
				style = props.button_style or "flib_slot_button_green",
			}, {
				Pr({
					type = "label",
					style = "cs2_label_signal_count_inventory",
					ignored_by_interaction = true,
					caption = siglib.format_signal_count(qty),
				}),
			})
		end)
	end,
})
