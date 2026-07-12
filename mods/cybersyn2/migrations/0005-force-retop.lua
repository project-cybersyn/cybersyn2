local scheduler = require("lib.core.scheduler")

scheduler.call_global_at(game.tick + 1, { "cs2", "retopologize" })
