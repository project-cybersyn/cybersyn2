--------------------------------------------------------------------------------
-- Relm elements for displaying deliveries in the train GUI.
--------------------------------------------------------------------------------

local events = require("lib.core.event")
local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local pos_lib = require("lib.core.math.pos")
local gui_elements = require("scripts.gui.elements")
local siglib = require("lib.signal")
local nlib = require("lib.core.math.numeric")
local cs2 = _G.cs2

local HF = ultros.HFlow
local VF = ultros.VFlow
local Pr = relm.Primitive

local lib = {}

local function on_click_focus_on(entity)
	return function(me, event)
		if entity and entity.valid then
			local player = game.get_player(event.player_index)
			if player and player.valid then player.centered_on = entity end
		end
	end
end

local function on_click_cancel_delivery(delivery_id)
	return function(me, event)
		remote.call("cybersyn2", "fail_delivery", delivery_id, "CANCELLED_BY_USER")
	end
end

local MinimapButton = relm.define_element({
	name = "CS2.MinimapButton",
	render = function(props, state)
		local entity = props.entity
		local width = props.width or 100
		local height = props.height or 100

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
	end,
})

local MinimapLabelButton = relm.define_element({
	name = "CS2.MinimapLabelButton",
	render = function(props, state)
		local width = props.width or 100
		return ultros.Button({
			style = "train_status_button",
			caption = props.caption,
			width = width,
			on_click = on_click_focus_on(props.entity),
		})
	end,
})

local MAP_FRAME_WIDTH_PADDING = 24
local MAP_FRAME_HEIGHT_PADDING = 65

local LabeledMapFrame = relm.define_element({
	name = "CS2.LabeledMapFrame",
	render = function(props, state)
		local width = props.width or 150
		local height = props.height or 200

		return Pr({
			type = "frame",
			style = "train_with_minimap_frame",
			height = height,
			width = width,
			direction = "vertical",
		}, {
			MinimapLabelButton({
				entity = props.entity,
				caption = props.caption,
				width = width - MAP_FRAME_WIDTH_PADDING,
			}),
			MinimapButton({
				entity = props.entity,
				width = width - MAP_FRAME_WIDTH_PADDING,
				height = height - MAP_FRAME_HEIGHT_PADDING,
			}),
		})
	end,
})
lib.LabeledMapFrame = LabeledMapFrame

local TrainDeliveryCancelButton = relm.define_element({
	name = "CS2.TrainDeliveryCancelButton",
	render = function(props, state)
		local delivery = props.delivery --[[@as Cybersyn.TrainDelivery ]]
		relm_util.use_event("cs2.delivery_state_changed")

		return ultros.If(
			delivery:is_cancellable(),
			ultros.Button({
				caption = "Cancel Delivery",
				width = 336,
				on_click = on_click_cancel_delivery(delivery.id),
			})
		)
	end,
	message = function(me, message, props)
		if message.key == "cs2.delivery_state_changed" then
			if message[1] == props.delivery then relm.paint(me) end
			return true
		else
			return false
		end
	end,
})

local TrainManifest = relm.define_element({
	name = "CS2.TrainManifest",
	render = function(props, state)
		local delivery = props.delivery --[[@as Cybersyn.TrainDelivery ]]
		relm_util.use_event("cs2.delivery_state_changed")

		local buttons_table = {}
		for k, v in pairs(delivery.manifest or tlib.EMPTY) do
			local button = buttons_table[k]
			if not button then
				button = {}
				buttons_table[k] = button
			end
			button.signal = siglib.key_to_signal(k)
			button.count = v
		end
		for k, v in pairs(delivery.loaded or tlib.EMPTY) do
			local button = buttons_table[k]
			if not button then
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
			button.signal = siglib.key_to_signal(k)
			button.count = button.count or 0
			button.upper = v
		end

		return Pr({
			type = "frame",
			style = "relm_raised_frame",
			direction = "vertical",
			width = 336,
		}, {
			Pr({
				type = "frame",
				style = "relm_frame_slot_buttons_shallow",
				direction = "horizontal",
				width = 320,
			}, {
				ultros.SlotButtonTable({
					column_count = 8,
					buttons_table = buttons_table,
					uppers = true,
					style = "slot_table",
				}),
			}),
		})
	end,
	message = function(me, message, props)
		if message.key == "cs2.delivery_state_changed" then
			if message[1] == props.delivery and message[2] == "wait_to" then
				relm.paint(me)
			end
			return true
		else
			return false
		end
	end,
})

local delivery_state_friendly_names = {
	wait_from = "Queued for provider",
	to_from = "En route to provider",
	at_from = "At provider",
	interrupted_from = "Interrupted",
	interrupted_to = "Interrupted",
	wait_to = "Queued for requester",
	to_to = "En route to requester",
	at_to = "At requester",
	completed = "[color=green]Completed[/color]",
	failed = "[color=red]Failed[/color]",
}

local DeliveryHeader = relm.define("CS2.DeliveryHeader", function(props)
	local delivery = props.delivery --[[@as Cybersyn.TrainDelivery]]
	local delivery_id = delivery.id
	local state_tick = delivery.state_tick or 0
	local state_name = delivery_state_friendly_names[delivery.state] or "Unknown"
	relm_util.use_event_handler(
		"cs2.delivery_state_changed",
		function(me, _, changed_delivery)
			if changed_delivery.id == delivery_id then relm.paint(me) end
		end
	)

	return {
		ultros.TimedRepaintWrapper({
			---@param t int64
			render = function(t)
				local time_in_state = t - state_tick
				return ultros.RtLgLabel({
					"",
					"[font=default-large-bold]#",
					delivery_id,
					"[/font] ",
					state_name,
					" (",
					nlib.format_ticks(time_in_state),
					")",
				})
			end,
		}),
		Pr({
			type = "line",
		}),
	}
end)

local TrainDeliveryFrame = relm.define_element({
	name = "CS2.TrainDeliveryFrame",
	render = function(props, state)
		local delivery = props.delivery --[[@as Cybersyn.TrainDelivery ]]
		local from_stop = cs2.get_stop(delivery.from_id)
		local from_entity = nil
		local from_name = "Unknown"
		if from_stop then
			from_entity = from_stop.entity --[[@as LuaEntity]]
			from_name = from_entity.backer_name or "Unknown"
		end
		local to_stop = cs2.get_stop(delivery.to_id)
		local to_entity = nil
		local to_name = "Unknown"
		if to_stop then
			to_entity = to_stop.entity --[[@as LuaEntity]]
			to_name = to_entity.backer_name or "Unknown"
		end
		local cstrain = cs2.get_train(delivery.vehicle_id)
		local train_entity = nil
		if cstrain then train_entity = cstrain:get_stock() end
		local width = props.train_frame and 109 or 166

		return VF({
			ultros.If(props.show_header, DeliveryHeader({ delivery = delivery })),
			HF({
				LabeledMapFrame({
					entity = from_entity,
					caption = { "", "[item=train-stop] Provider" },
					width = width,
					height = 180,
				}),
				ultros.If(
					props.train_frame and train_entity,
					LabeledMapFrame({
						entity = train_entity,
						caption = { "", "[item=locomotive]" },
						width = width,
						height = 180,
					})
				),
				LabeledMapFrame({
					entity = to_entity,
					caption = { "", "[item=train-stop] Requester" },
					width = width,
					height = 180,
				}),
			}),
			TrainManifest({ delivery = delivery }),
			TrainDeliveryCancelButton({ delivery = delivery }),
		})
	end,
})
lib.TrainDeliveryFrame = TrainDeliveryFrame

local function default_delivery_sort(a, b)
	return a.created_tick > b.created_tick
end

local DeliveryList = relm.define("NodeGui.DeliveryList", function(props)
	local list = props.base_list
	local tbl = props.base_table or storage.deliveries
	local filter = props.filter or function() return true end
	local limit = props.limit or 3
	local sort = props.sort or default_delivery_sort
	local show_header = props.show_header
	local show_train = props.show_train

	relm_util.use_event_handler(
		"cs2.delivery_state_changed",
		---@param changed_delivery Cybersyn.Delivery
		function(me, _, changed_delivery)
			if filter(changed_delivery) then relm.paint(me) end
		end
	)

	local deliveries = tlib.EMPTY
	if list then
		deliveries = tlib.filter(list, filter)
	elseif tbl then
		deliveries = tlib.t_map_a(tbl, function(delivery)
			if filter(delivery) then return delivery end
		end)
	end

	table.sort(deliveries, sort)

	for i = #deliveries, limit + 1, -1 do
		deliveries[i] = nil
	end

	local children = tlib.map(deliveries, function(delivery)
		local really_show_train = false
		if show_train == true then
			really_show_train = true
		elseif
			show_train ~= false and (not delivery:is_successfully_completed())
		then
			really_show_train = true
		end
		return TrainDeliveryFrame({
			delivery = delivery,
			show_header = show_header,
			train_frame = really_show_train,
		})
	end)

	return children
end)
lib.DeliveryList = DeliveryList

return lib
