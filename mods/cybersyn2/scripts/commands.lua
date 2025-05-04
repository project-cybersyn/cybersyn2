--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

local cs2 = _G.cs2

commands.add_command("cs2", nil, function(command)
	local arg = command.parameter
	if arg == "debugger" then
		cs2.debug.open_debugger(command.player_index)
		return
	elseif arg == "check_surfaces" then
		cs2.recheck_train_surfaces()
		return
	elseif arg == "log_all" then
		cs2.debug.set_strace(0, 0, nil)
		return
	end
end)
