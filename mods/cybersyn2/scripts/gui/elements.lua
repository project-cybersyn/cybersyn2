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
local pairs = pairs
local key_to_signal = siglib.key_to_signal

local lib = {}

local SignalCountsTable = relm.define_element({
	name = "CS2.SignalCountsTable",
	render = function(props)
		local signal_counts = props.signal_counts or EMPTY

		---@type Ultros.SignalButtonInfo[]
		local buttons = {}

		for k, count in pairs(signal_counts) do
			buttons[#buttons + 1] = {
				signal = key_to_signal(k),
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

local function on_click_focus_on(entity)
	return function(me, event)
		if entity and entity.valid then
			local player = game.get_player(event.player_index)
			if player and player.valid then player.centered_on = entity end
		end
	end
end

local MinimapButton = relm.define(
	"CS2.MinimapButton",
	---@param props {entity: LuaEntity?, width?: number, height?: number}
	function(props)
		local entity = props.entity
		local width = props.width or 100
		local height = props.height or 100

		if entity and entity.valid then
			return ultros.Button({
				style = "locomotive_minimap_button",
				width = width,
				height = height,
				on_click = on_click_focus_on(entity),
			}, {
				Pr({
					type = "minimap",
					width = width,
					height = height,
					entity = entity,
				}),
			})
		else
			return Pr({ type = "empty-widget", width = width, height = height })
		end
	end
)
lib.MinimapButton = MinimapButton

local Manifest = relm.define(
	"CS2.Manifest",
	---@param props {delivery?: Cybersyn.Delivery, column_count?: integer, limit?: integer, height?: integer}
	function(props)
		local delivery = props.delivery
		local delivery_id = delivery and delivery.id
		local column_count = props.column_count or 8
		local width = 40 * column_count
		local limit = props.limit or 1000000
		local manifest = (delivery and delivery.manifest) or EMPTY
		local loaded = (delivery and delivery.loaded) or EMPTY

		relm_util.use_event_handler(
			"cs2.delivery_state_changed",
			function(me, _, changed_delivery, state)
				if changed_delivery.id == delivery_id and state == "wait_to" then
					relm.paint(me)
				end
			end
		)

		local buttons_table = {}
		local n = 0
		for k, v in pairs(manifest) do
			local button = buttons_table[k]
			if not button then
				n = n + 1
				if n > limit then break end
				button = {}
				buttons_table[k] = button
			end
			button.signal = key_to_signal(k)
			button.count = v
		end

		for k, v in pairs(loaded or EMPTY) do
			local button = buttons_table[k]
			if not button then
				n = n + 1
				if n > limit then goto continue end
				button = {}
				buttons_table[k] = button
			end
			local expected = button.count or 0
			if v > expected then
				button.button_style = "relm_slot_button_yellow"
			elseif v < expected then
				button.button_style = "relm_slot_button_red"
			else
				button.button_style = "relm_slot_button_green"
			end
			button.signal = key_to_signal(k)
			button.count = button.count or 0
			button.upper = v
			::continue::
		end

		return Pr({
			type = "frame",
			style = "relm_frame_slot_buttons_shallow",
			direction = "horizontal",
			width = width,
			height = props.height,
		}, {
			ultros.SlotButtonTable({
				column_count = column_count,
				buttons_table = buttons_table,
				uppers = true,
				style = "slot_table",
			}),
		})
	end
)
lib.Manifest = Manifest

return lib
