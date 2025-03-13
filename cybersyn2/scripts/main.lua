local counters = require("__cybersyn2__.lib.counters")
local scheduler = require("__cybersyn2__.lib.scheduler")

-- Initialize sublibraries
on_init(counters.init, true)
on_init(scheduler.init, true)

-- Core game events
script.on_init(raise_init)
script.on_configuration_changed(raise_configuration_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, handle_runtime_mod_setting_changed)
script.on_nth_tick(nil)
script.on_nth_tick(1, scheduler.tick)
