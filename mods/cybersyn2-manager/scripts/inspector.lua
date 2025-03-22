_G.mgr.inspector = {}
local mgr = _G.mgr

_G.mgr.INSPECTOR_WINDOW_NAME = "cybersyn2-inspector"

local function get_or_create_inspector_state(player_index)
	local pstate = storage.players[player_index]
	if not pstate then
		storage.players[player_index] = {}
		pstate = storage.players[player_index]
	end
	local istate = pstate.inspector
	if not istate then
		pstate.inspector = {
			entries = {},
		}
		istate = pstate.inspector
	end
	return istate
end

local function destroy_inspector_state(player_index)
	local pstate = storage.players[player_index]
	if not pstate then return end
	pstate.inspector = nil
end

function _G.mgr.inspector.is_open(player_index)
	local player = game.get_player(player_index)
	if not player then return false end
	local gui_root = player.gui.screen
	if gui_root[mgr.INSPECTOR_WINDOW_NAME] then return true end
	return false
end
