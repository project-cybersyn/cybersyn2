--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

local cs2 = _G.cs2

commands.add_command(
	"cs2-reset",
	{ "cybersyn2-commands.reset-command-help" },
	function() cs2.try_reset() end
)

commands.add_command(
	"cs2-force-reset",
	{ "cybersyn2-commands.force-reset-command-help" },
	function() cs2.reset() end
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
