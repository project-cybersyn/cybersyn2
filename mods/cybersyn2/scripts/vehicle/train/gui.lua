--------------------------------------------------------------------------------
-- Train/Group management GUI.
-- This GUI is attached to the Train window when a train is selected in game.
--------------------------------------------------------------------------------

local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local pos_lib = require("lib.core.math.pos")
local cs2 = _G.cs2

local HF = ultros.HFlow
local VF = ultros.VFlow
local Pr = relm.Primitive

local ROLLING_STOCK_TYPES = cs2.ROLLING_STOCK_TYPES
local GUI_WINDOW_NAME = "Cs2TrainGui"

---@param player LuaPlayer
local function get_train_gui_pos(player)
	local player_state = cs2.get_player_state(player.index)
	if player_state and player_state.train_gui_pos then
		return player_state.train_gui_pos
	end
	-- Default pos.
	local scale = player.display_scale
	return { x = 452 * scale, y = 40 * scale }
end

---@param player LuaPlayer
local function close_train_gui(player)
	local elt = player.gui.screen[GUI_WINDOW_NAME]
	if elt and elt.valid then
		local id = relm.get_root_id(elt)
		if id then relm.root_destroy(id) end
		if elt.valid then elt.destroy() end
	end
end

local Group = relm.define_element({
	name = "TrainGui.Group",
	render = function(props, state)
		---@cast state table
		relm_util.use_event("cs2.group_train_added")
		relm_util.use_event("cs2.group_settings_changed")
		local group = state.group --[[@as Cybersyn.Internal.TrainGroup]]
		local gname = (group and group.name) or "No group"

		return ultros.If(
			group,
			ultros.WellSection({ caption = { "", "Group: " .. gname } }, {
				ultros.Checkbox({
					caption = "Enable logistics",
					tooltip = "If checked, trains from this group are eligible for dispatch by Cybersyn. If unchecked, they will not be dispatched. (Deliveries that have already been dispatched will still be completed.)",
					value = not group.decomissioned,
					on_change = function(_, st)
						cs2.set_train_group_decomissioned(group, not st)
					end,
				}),
			})
		)
	end,
	state = function(props)
		local cstrain = props.cstrain --[[@as Cybersyn.Train]]
		local gn = cstrain and cstrain.group
		local group = gn and cs2.get_train_group(gn)
		if group then
			return { group = group }
		else
			return {}
		end
	end,
	message = function(me, payload, props, state)
		---@cast state table
		if payload.key == "cs2.group_train_added" then
			local cstrain = props.cstrain --[[@as Cybersyn.Train]]
			local gn = cstrain and cstrain.group
			local group = gn and cs2.get_train_group(gn)
			if group ~= state.group then relm.set_state(me, { group = group }) end
			return true
		elseif payload.key == "cs2.group_settings_changed" then
			if payload[1] == state.group then
				relm.paint(me)
				return true
			end
			return true
		end
		return false
	end,
})

local Delivery = relm.define_element({
	name = "TrainGui.Delivery",
	render = function(props, state)
		return ultros.WellSection({ caption = "Delivery" })
	end,
	state = function(props) return {} end,
})

local CsTrain = relm.define_element({
	name = "TrainGui.CsTrain",
	render = function(props, state)
		return {
			Group(props),
			Delivery(props),
		}
	end,
	state = function(props) return {} end,
})

relm.define_element({
	name = "TrainGui",
	render = function(props, state)
		local luatrain = props.luatrain --[[@as LuaTrain?]]
		local cstrain = luatrain
			and luatrain.valid
			and cs2.get_train_from_luatrain_id(luatrain.id)

		relm_util.use_event("cs2.group_train_added")
		relm_util.use_event("cs2.vehicle_destroyed")

		return ultros.WindowFrame({
			caption = "[virtual-signal=cybersyn2] Cybersyn 2 Train",
			closable = false,
		}, {
			Pr({
				type = "frame",
				style = "inside_shallow_frame",
				direction = "vertical",
				width = 340,
				minimal_height = 400,
				horizontally_stretchable = false,
				vertically_stretchable = true,
			}, {
				Pr({
					type = "scroll-pane",
					direction = "vertical",
					vertically_stretchable = true,
					horizontal_scroll_policy = "never",
					extra_top_padding_when_activated = 0,
					extra_left_padding_when_activated = 0,
					extra_right_padding_when_activated = 0,
					extra_bottom_padding_when_activated = 0,
				}, {
					ultros.If(
						cstrain,
						CsTrain({ cstrain = cstrain, luatrain = luatrain })
					),
					ultros.If(
						not cstrain,
						ultros.RtMultilineLabel(
							"This train is not managed by Cybersyn 2. Add it to a group beginning with [virtual-signal=cybersyn2]."
						)
					),
				}),
			}),
		})
	end,
	state = function(props)
		local luatrain = props.luatrain --[[@as LuaTrain?]]
		local cstrain = luatrain
			and luatrain.valid
			and cs2.get_train_from_luatrain_id(luatrain.id)
		return cstrain and { cstrain = cstrain } or {}
	end,
	message = function(me, payload, props, state)
		---@cast state table
		if
			payload.key == "cs2.group_train_added"
			or payload.key == "cs2.vehicle_destroyed"
		then
			local luatrain = props.luatrain --[[@as LuaTrain?]]
			local cstrain = luatrain
				and luatrain.valid
				and cs2.get_train_from_luatrain_id(luatrain.id)
			if (not cstrain) or (not cstrain:is_valid()) then cstrain = nil end
			if cstrain ~= state.cstrain then
				relm.set_state(me, { cstrain = cstrain })
			end
			return true
		end
		return false
	end,
})

events.bind(defines.events.on_gui_opened, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end
	if event.gui_type ~= defines.gui_type.entity then return end
	local train_entity = player.opened --[[@as LuaEntity?]]
	if
		not train_entity
		or not train_entity.valid
		or not ROLLING_STOCK_TYPES[train_entity.type]
	then
		return
	end
	local luatrain = train_entity.train
	if not luatrain then return end

	close_train_gui(player)

	local _, elt = relm.root_create(
		player.gui.screen,
		GUI_WINDOW_NAME,
		"TrainGui",
		{ train_entity = train_entity, luatrain = luatrain }
	)

	if elt then elt.location = get_train_gui_pos(player) end
end)

events.bind(defines.events.on_gui_closed, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end
	if event.gui_type ~= defines.gui_type.entity then return end
	local train_entity = event.entity --[[@as LuaEntity?]]
	if not train_entity or not ROLLING_STOCK_TYPES[train_entity.type] then
		return
	end

	local elt = player.gui.screen[GUI_WINDOW_NAME]
	if not elt or not elt.valid then return end

	local st = cs2.get_or_create_player_state(player.index)
	local x, y = pos_lib.pos_get(elt.location)
	st.train_gui_pos = { x, y }

	close_train_gui(player)
end)
