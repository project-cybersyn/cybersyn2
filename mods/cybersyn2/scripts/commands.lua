--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

local cs2 = _G.cs2

commands.add_command(
	"cs2-shutdown",
	{ "cybersyn2-commands.shutdown-command-help" },
	function(ev)
		if ev.parameter == "force" then
			cs2.shutdown(true)
		else
			cs2.shutdown(false)
		end
	end
)

commands.add_command(
	"cs2-restart",
	{ "cybersyn2-commands.restart-command-help" },
	function() cs2.restart() end
)

commands.add_command(
	"cs2-debugger",
	{ "cybersyn2-commands.debugger-command-help" },
	function(command) cs2.debug.open_debugger(command.player_index) end
)

commands.add_command(
	"cs2-log-all",
	{ "cybersyn2-commands.log-all-command-help" },
	function() cs2.debug.set_strace(0, 0, nil) end
)
