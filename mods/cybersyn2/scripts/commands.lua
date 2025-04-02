--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

local cs2 = _G.cs2

commands.add_command("cybersyn2", nil, function(command)
	local arg = command.parameter
	if command.parameter == "debugger" then
		cs2.debug.open_debugger(command.player_index)
		return
	elseif arg == "log_all" then
		cs2.debug.set_strace(0, 0, nil)
	end
end)
