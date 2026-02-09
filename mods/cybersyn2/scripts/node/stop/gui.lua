--------------------------------------------------------------------------------
-- Stop management GUI.
-- This GUI is attached to the Stop window when a stop is selected in game.
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

local GUI_WINDOW_NAME = "Cs2StopGui"

---@param player LuaPlayer
local function get_stop_gui_pos(player)
	local player_state = cs2.get_player_state(player.index)
	if player_state and player_state.stop_gui_pos then
		return player_state.stop_gui_pos
	end
	-- Default pos.
	local scale = player.display_scale
	return { x = 0, y = 0 }
end

---@param player LuaPlayer
local function close_stop_gui(player)
	local elt = player.gui.screen[GUI_WINDOW_NAME]
	if elt and elt.valid then
		local id = relm.get_root_id(elt)
		if id then relm.root_destroy(id) end
		if elt.valid then elt.destroy() end
	end
end

relm.define_element({
	name = "StopGui",
	render = function(props, state)
		return ultros.WindowFrame({
			caption = "[virtual-signal=cybersyn2] Cybersyn 2 Stop",
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
				}, {}),
			}),
		})
	end,
	state = function(props) return {} end,
	message = function(me, payload, props, state)
		---@cast state table
		return false
	end,
})

events.bind(defines.events.on_gui_opened, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end
	if event.gui_type ~= defines.gui_type.entity then return end
	local stop_entity = player.opened --[[@as LuaEntity?]]
	if
		not stop_entity
		or not stop_entity.valid
		or stop_entity.type ~= "train-stop"
	then
		return
	end

	close_stop_gui(player)

	local _, elt = relm.root_create(
		player.gui.screen,
		GUI_WINDOW_NAME,
		"StopGui",
		{ stop_entity = stop_entity }
	)

	if elt then elt.location = get_stop_gui_pos(player) end
end)

events.bind(defines.events.on_gui_closed, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end
	if event.gui_type ~= defines.gui_type.entity then return end
	local stop_entity = event.entity --[[@as LuaEntity?]]
	if not stop_entity or stop_entity.type ~= "train-stop" then return end

	local elt = player.gui.screen[GUI_WINDOW_NAME]
	if not elt or not elt.valid then return end

	local st = cs2.get_or_create_player_state(player.index)
	local x, y = pos_lib.pos_get(elt.location)
	st.stop_gui_pos = { x, y }
	close_stop_gui(player)
end)
