inspector = {}

INSPECTOR_WINDOW_NAME = "cybersyn2-inspector"

local function create_inspector_state(player_index)
end

function inspector.is_open(player_index)
	local player = game.get_player(player_index)
	if not player then return false end
	local gui_root = player.gui.screen
	if gui_root[INSPECTOR_WINDOW_NAME] then return true end
	return false
end
