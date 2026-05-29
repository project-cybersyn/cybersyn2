local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local pos_lib = require("lib.core.math.pos")
local cs2 = _G.cs2
local tlib = require("lib.core.table")
local siglib = require("lib.signal")

local HF = ultros.HFlow
local VF = ultros.VFlow
local Pr = relm.Primitive
local EMPTY = tlib.EMPTY

local lib = {}

local SignalCountsTable = relm.define_element({
	name = "CS2.SignalCountsTable",
	render = function(props)
		local signal_counts = props.signal_counts or EMPTY

		---@type Ultros.SignalButtonInfo[]
		local buttons = {}

		for k, count in pairs(signal_counts) do
			buttons[#buttons + 1] = {
				signal = siglib.key_to_signal(k),
				count = count,
			}
		end

		return ultros.SlotButtonTable({
			buttons = buttons,
			column_count = props.column_count or 5,
			style = props.style,
		})
	end,
})
lib.SignalCountsTable = SignalCountsTable

return lib
