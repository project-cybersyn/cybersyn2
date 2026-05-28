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

local function noop() end

relm.define("StopGui", function(props)
	-- Window management
	local root_id, player_index = props.root_id, props.player_index

	local function _close_me() relm.root_destroy(root_id) end

	local pinned, set_pinned = ultros.use_pinnable()

	local close_me = ultros.use_memoized_window_position(_close_me, function()
		local player_state = cs2.get_player_state(player_index)
		return player_state and player_state.stop_gui_pos
	end, pinned and noop or function(loc)
		local player_state = cs2.get_or_create_player_state(player_index)
		player_state.stop_gui_pos = loc
	end, function(elt) elt.force_auto_center() end)

	ultros.use_close_on_gui_closed(player_index, close_me, pinned)

	return ultros.WindowFrame({
		caption = "[virtual-signal=cybersyn2] Cybersyn 2 Stop",
		on_close = close_me,
		decoration = function()
			return ultros.PinButton({ pinned = pinned, set_pinned = set_pinned })
		end,
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
end)

-- Game events
-- Don't bind these in recovery mode

---@diagnostic disable-next-line: undefined-field
if _G.__RECOVERY_MODE__ then return end

events.bind(
	"cs2.combinator_gui_opened",
	---@param comb Cybersyn.Combinator
	---@param player LuaPlayer
	function(comb, player)
		if comb.mode ~= "station" then return end
		local node = comb:get_node("stop") --[[@as Cybersyn.TrainStop?]]
		if not node then return end

		local _, elt =
			relm.root_create(player.gui.screen, nil, "StopGui", { stop = node })
	end
)
