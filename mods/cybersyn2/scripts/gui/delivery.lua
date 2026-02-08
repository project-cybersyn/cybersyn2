--------------------------------------------------------------------------------
-- Relm elements for displaying deliveries in the train GUI.
--------------------------------------------------------------------------------

local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local pos_lib = require("lib.core.math.pos")
local gui_elements = require("scripts.gui.elements")
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
				width = 322,
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

local TrainManifestFrames = relm.define_element({
	name = "CS2.TrainManifestFrames",
	render = function(props, state)
		local delivery = props.delivery
		relm_util.use_event("cs2.delivery_state_changed")

		return {
			Pr({
				type = "frame",
				style = "relm_raised_frame",
				direction = "vertical",
				width = 322,
			}, {
				ultros.BoldLabel("Manifest"),
				gui_elements.SignalCountsTable({
					column_count = 6,
					signal_counts = delivery.manifest,
					style = "slot_table",
				}),
			}),
			ultros.CallIf(
				delivery.loaded,
				function(d)
					return Pr({
						type = "frame",
						style = "relm_raised_frame",
						direction = "vertical",
						width = 322,
					}, {
						ultros.BoldLabel("Loaded Cargo"),
						gui_elements.SignalCountsTable({
							column_count = 6,
							signal_counts = d.loaded,
							style = "slot_table",
						}),
					})
				end,
				delivery
			),
		}
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

local TrainDeliveryFrame = relm.define_element({
	name = "CS2.TrainDeliveryFrame",
	render = function(props, state)
		local delivery = props.delivery --[[@as Cybersyn.TrainDelivery ]]
		local from_stop = cs2.get_stop(delivery.from_id)
		local from_entity = nil
		local from_name = "Unknown"
		if from_stop then
			from_entity = from_stop.entity --[[@as LuaEntity]]
			from_name = from_entity.backer_name
		end
		local to_stop = cs2.get_stop(delivery.to_id)
		local to_entity = nil
		local to_name = "Unknown"
		if to_stop then
			to_entity = to_stop.entity --[[@as LuaEntity]]
			to_name = to_entity.backer_name
		end

		return VF({
			HF({
				LabeledMapFrame({
					entity = from_entity,
					caption = from_name,
					width = 159,
					height = 180,
				}),
				LabeledMapFrame({
					entity = to_entity,
					caption = to_name,
					width = 159,
					height = 180,
				}),
			}),
			TrainManifestFrames({ delivery = delivery }),
			TrainDeliveryCancelButton({ delivery = delivery }),
		})
	end,
})
lib.TrainDeliveryFrame = TrainDeliveryFrame

return lib
