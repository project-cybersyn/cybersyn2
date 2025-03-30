--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

local function loop_debugger(player_index)
	_G.cs2.debug.open_loop_debugger(player_index)
end

commands.add_command("cybersyn2", nil, function(command)
	if command.parameter == "loop_debugger" then
		loop_debugger(command.player_index)
	end
end)
