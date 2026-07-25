--------------------------------------------------------------------------------
-- Train/Group management GUI.
-- This GUI is attached to the Train window when a train is selected in game.
--------------------------------------------------------------------------------

local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local pos_lib = require("lib.core.math.pos")
local delivery_gui = require("scripts.gui.delivery")
local tlib = require("lib.core.table")
local siglib = require("lib.core.signal")
local cs2 = _G.cs2

local HF = ultros.HFlow
local VF = ultros.VFlow
local Pr = relm.Primitive

local function noop() end

local TrainInfo = relm.define("TrainGui.TrainInfo", function(props)
	local cstrain = props.cstrain --[[@as Cybersyn.Train]]

	relm_util.use_event_handler(
		"cs2.vehicle_topology_changed",
		function(me, _, vehicle)
			if vehicle.id == cstrain.id then relm.paint(me) end
		end
	)

	local tid = cstrain:get_topology_id()
	local dtid = cstrain.default_topology_id
	local tname = cs2.get_topology_name(tid) or "<unknown>"
	if siglib.key_is_virtual(tname) then
		tname = "[virtual-signal=" .. tname .. "]"
	end
	local dtname = cs2.get_topology_name(dtid) or "<unknown>"
	if siglib.key_is_virtual(dtname) then
		dtname = "[virtual-signal=" .. dtname .. "]"
	end
	local topology_text = (tid == dtid) and tname
		or tname .. " (default: " .. dtname .. ")"

	local text = {
		"",
		"[font=default-bold]Topology:[/font] ",
		topology_text,
		"\n[font=default-bold]Capacity:[/font] ",
		cstrain.item_slot_capacity,
		" item slots, ",
		cstrain.fluid_capacity,
		" fluids",
	}

	return ultros.WellSection({ caption = "Train Info" }, {
		ultros.RtMultilineLabel(text),
	})
end)

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
					caption = "Enable logistics for group",
					tooltip = "If checked, trains in this group are eligible for dispatch by Cybersyn. If unchecked, Cybersyn will not dispatch trains in this group. (Deliveries that have already been dispatched will still be completed.)",
					value = not group.decomissioned,
					on_change = function(_, st)
						cs2.set_train_group_decomissioned(group, not st)
					end,
				}),
				ultros.Labeled({ caption = "Topology" }, {
					ultros.SignalPicker({
						tooltip = "The topology assigned to trains in this group. If no topology is selected, the default topology will be used.",
						virtual_signal = group.topology,
						on_change = function(_, signal, elem)
							if not signal then
								cs2.set_train_group_topology(group, nil)
							elseif signal.type == "virtual" then
								cs2.set_train_group_topology(group, signal.name)
							else
								game.print(
									{ "cybersyn2-gui.virtual-signals-only" },
									cs2.ERROR_PRINT_OPTS
								)
								elem.elem_value = nil
							end
						end,
					}),
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
		local cstrain = props.cstrain --[[@as Cybersyn.Train]]

		local delivery = cstrain.delivery_id
			and cs2.get_delivery(cstrain.delivery_id)
		relm_util.use_event("cs2.vehicle_delivery_set")
		relm_util.use_event("cs2.vehicle_delivery_cleared")

		return delivery
			and ultros.WellSection({ caption = "Current Delivery" }, {
				delivery_gui.TrainDeliveryFrame({
					show_header = true,
					delivery = delivery,
				}),
			})
	end,
	state = function(props) return {} end,
	message = function(me, payload, props, state)
		if
			payload.key == "cs2.vehicle_delivery_set"
			or payload.key == "cs2.vehicle_delivery_cleared"
		then
			local cstrain = props.cstrain --[[@as Cybersyn.Train]]
			if payload[1] == cstrain then relm.paint(me) end
			return true
		end
		return false
	end,
})

local DeliveryHistory = relm.define("TrainGui.DeliveryHistory", function(props)
	local id = props.cstrain.id

	return ultros.WellSection({ caption = "Delivery History" }, {
		delivery_gui.DeliveryList({
			filter = function(delivery)
				return (delivery.vehicle_id == id) and delivery:is_in_final_state()
			end,
			show_header = true,
			show_train = false,
		}),
	})
end)

local CsTrain = relm.define(
	"TrainGui.CsTrain",
	function(props)
		return {
			TrainInfo(props),
			Group(props),
			Delivery(props),
			DeliveryHistory(props),
		}
	end
)

-- Top-level Train GUI
relm.define("TrainGui", function(props)
	local luatrain = props.luatrain --[[@as LuaTrain?]]
	local luatrain_valid = not not (luatrain and luatrain.valid)
	---@diagnostic disable-next-line: need-check-nil
	local luatrain_id = luatrain_valid and luatrain.id or 0
	local cstrain = relm.use_result(
		function()
			return luatrain_valid and cs2.get_train_from_luatrain_id(luatrain_id)
		end
	)
	local window_height = cstrain and 800 or 100

	-- Window management
	local root_id, player_index = props.root_id, props.player_index
	local function _close_me() relm.root_destroy(root_id) end
	local pinned, set_pinned = ultros.use_pinnable()
	local close_me = ultros.use_memoized_window_position(
		_close_me,
		function()
			local player_state = cs2.get_player_state(player_index)
			return player_state and player_state.train_gui_pos
		end,
		pinned and noop
			or function(loc)
				local player_state = cs2.get_or_create_player_state(player_index)
				player_state.train_gui_pos = loc
			end,
		function(elt) -- Default pos.
			local player = game.get_player(player_index)
			if not player then return end
			local scale = player.display_scale
			elt.location = { math.floor(452 * scale), math.floor(40 * scale) }
		end
	)
	ultros.use_close_on_gui_closed(
		player_index,
		close_me,
		pinned,
		defines.gui_type.entity
	)

	-- A new train was added to a group.
	relm_util.use_event_handler(
		"cs2.group_train_added",
		function(me, _, group, vehicle)
			---@cast vehicle Cybersyn.Train
			if vehicle.type ~= "train" then return end
			if vehicle.lua_train ~= luatrain then return end
			relm.paint(me)
		end
	)

	-- A train was removed.
	relm_util.use_event_handler("cs2.vehicle_destroyed", function(me, _, vehicle)
		if (not luatrain) or not luatrain.valid then
			relm.root_destroy(props.root_id)
			return
		end
		relm.paint(me)
	end)

	-- A train was destroyed mysteriously
	relm.use_effect(luatrain_id, function()
		if luatrain and luatrain.valid then
			script.register_on_object_destroyed(luatrain)
		end
	end)
	relm_util.use_event_handler("on_object_destroyed", function(me, _, ev)
		if (not luatrain) or not luatrain.valid then
			relm.root_destroy(props.root_id)
			return
		end
	end)

	return ultros.WindowFrame({
		caption = {
			"",
			"[virtual-signal=cybersyn2] Train ",
			cstrain and cstrain.id or "",
		},
		on_close = close_me,
		decoration = function()
			return ultros.PinButton({ pinned = pinned, set_pinned = set_pinned })
		end,
	}, {
		Pr({
			type = "frame",
			style = "inside_shallow_frame",
			direction = "vertical",
			width = 366,
			height = window_height,
			horizontally_stretchable = false,
			vertically_stretchable = false,
		}, {
			Pr({
				type = "scroll-pane",
				direction = "vertical",
				vertically_stretchable = true,
				horizontal_scroll_policy = "never",
				vertical_scroll_policy = "always",
				extra_top_padding_when_activated = 0,
				extra_left_padding_when_activated = 0,
				extra_right_padding_when_activated = 0,
				extra_bottom_padding_when_activated = 0,
			}, {
				ultros.If(cstrain, CsTrain({ cstrain = cstrain, luatrain = luatrain })),
				ultros.If(
					not cstrain,
					ultros.RtMultilineLabel(
						"This train is not managed by Cybersyn 2. Add it to a group beginning with [virtual-signal=cybersyn2]. (There must also be a Cybersyn 2 station within the surface or topology where the train is located.)"
					)
				),
			}),
		}),
	})
end)

-- Game events
-- Don't bind these in recovery mode

---@diagnostic disable-next-line: undefined-field
if _G.__RECOVERY_MODE__ then return end

events.bind(defines.events.on_gui_opened, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end
	if event.gui_type ~= defines.gui_type.entity then return end
	local train_entity = player.opened --[[@as LuaEntity?]]
	if
		not train_entity
		or not train_entity.valid
		or train_entity.type ~= "locomotive"
	then
		return
	end
	local luatrain = train_entity.train
	if not luatrain then return end

	local _, elt = relm.root_create(
		player.gui.screen,
		nil,
		"TrainGui",
		{ train_entity = train_entity, luatrain = luatrain }
	)
end)
