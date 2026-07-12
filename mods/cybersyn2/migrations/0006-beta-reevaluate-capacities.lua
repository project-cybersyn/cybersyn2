local scheduler = require("lib.core.scheduler")

scheduler.call_global_at(
	game.tick + 2,
	{ "cs2", "reevaluate_all_stop_capacities" }
)
