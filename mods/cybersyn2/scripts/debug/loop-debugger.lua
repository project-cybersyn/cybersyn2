--------------------------------------------------------------------------------
-- Logistics thread state debugger
--------------------------------------------------------------------------------

local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local cs2 = _G.cs2

relm.define_element({
	name = "LogisticsLoopDebugger",
	render = function(props, state)
		return ultros.WindowFrame({
			caption = "Logistics Loop Debugger",
		}, {
			ultros.Button({ caption = "Pause", on_click = "pause" }),
			ultros.Button({ caption = "Step", on_click = "step" }),
		})
	end,
	message = function(me, payload, props)
		local data = cs2.debug.get_logistics_thread_data() or {}
		if payload.key == "close" then
			relm.root_destroy(props.root_id)
		elseif payload.key == "pause" then
			data.paused = not data.paused
		elseif payload.key == "step" then
			data.stepped = true
		end
	end,
})

---@param player_index int
function _G.cs2.debug.open_loop_debugger(player_index)
	local player = game.get_player(player_index)
	if not player then return end
	local screen = player.gui.screen
	if screen["LogisticsLoopDebugger"] then return end
	relm.root_create(screen, "LogisticsLoopDebugger", {}, "LogisticsLoopDebugger")
end
