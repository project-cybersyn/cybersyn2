-- Unique global table to avoid polluting `_G`.
cs2 = {
	remote_api = {},
	gui = {},
	lib = {},
	debug = {},
}

-- Bootstrap logging
local strace = require("lib.core.strace")
strace.set_handler(strace.standard_log_handler)

-- Bootstrap relm
local relm = require("lib.core.relm.relm")
local event = require("lib.core.event")
relm.bootstrap_with_core_events(event)

require("scripts.types")
require("scripts.constants")
require("scripts.events")
require("scripts.storage")
require("scripts.reset")
require("scripts.settings")
require("scripts.lib")

require("scripts.api.plugins.route")
require("scripts.logistics.order")
require("scripts.logistics.inventory") -- needs order
require("scripts.logistics.delivery.base")

require("scripts.combinator.base")
require("scripts.combinator.settings")
require("scripts.combinator.lifecycle")
require("scripts.combinator.mode")
require("scripts.combinator.gui.base")
require("scripts.combinator.gui.elements")
require("scripts.combinator.connection")

require("scripts.node.base") -- needs inventory
require("scripts.node.topology")
require("scripts.node.stop.base") -- needs delivery
require("scripts.node.stop.lifecycle") -- needs delivery, combinator
require("scripts.node.stop.layout.base")
require("scripts.node.stop.layout.equipment")
require("scripts.node.stop.layout.pattern")
require("scripts.node.stop.allow")
require("scripts.node.stop.capacity")
require("scripts.node.gui")

require("scripts.vehicle.base")
require("scripts.vehicle.train.base")
require("scripts.vehicle.train.lifecycle")
require("scripts.vehicle.train.layout")
require("scripts.vehicle.train.gui")

require("scripts.logistics.delivery.train") -- needs inventory, trainstop, train

require("scripts.combinator.modes.station")
require("scripts.combinator.modes.allow")
require("scripts.combinator.modes.dt")
require("scripts.combinator.modes.manifest")
require("scripts.combinator.modes.wagon")
require("scripts.combinator.modes.inventory")
require("scripts.combinator.modes.deliveries")
require("scripts.combinator.modes.surface")
require("scripts.combinator.modes.wagon-contents")
require("scripts.combinator.modes.wagon-split")

-- Threads
require("scripts.tasks.base")
require("scripts.tasks.train-monitor")
require("scripts.tasks.delivery-monitor")
require("scripts.tasks.delivery-dispatch")
-- Dispatch loop threads
require("scripts.tasks.dispatch-loop.base")
require("scripts.tasks.dispatch-loop.enum-nodes")
require("scripts.tasks.dispatch-loop.poll-nodes")
require("scripts.tasks.dispatch-loop.logistics")

require("scripts.alerts.alerts")
require("scripts.alerts.station")
require("scripts.alerts.train")

require("scripts.debug.base")
require("scripts.debug.overlay")
require("scripts.debug.debugger")

require("scripts.api.base")
require("scripts.api.query")
require("scripts.api.queries.meta")
require("scripts.api.queries.objects")

remote.add_interface("cybersyn2", _G.cs2.remote_api)

require("scripts.commands")

-- Main should run last.
require("scripts.main")

-- Enable support for the Global Variable Viewer debugging mod, if it is
-- installed.
---@diagnostic disable-next-line: unresolved-require
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
