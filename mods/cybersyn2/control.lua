-- Unique global table to avoid polluting `_G`.
--
-- Whenever setting a global, always use `_G.cs2.x.y = ...`
-- as sumneko code completion gets confused otherwise.
_G.cs2 = {
	remote_api = {},
	gui = {},
	lib = {},
	---All combinator setting definitions.
	---@type {[string]: Cybersyn.Combinator.SettingDefinition}
	combinator_settings = {},
	---Debug APIs, do not use.
	debug = {},
}

local strace = require("lib.core.strace")

strace.set_handler(strace.standard_log_handler)

require("scripts.types")
require("scripts.constants")
require("scripts.events")
require("scripts.storage")
require("scripts.reset")
require("scripts.settings")
require("scripts.lib")
require("scripts.threads")
require("scripts.alerts")

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

require("scripts.node.base") -- needs inventory
require("scripts.node.topology")
require("scripts.node.stop.base") -- needs delivery
require("scripts.node.stop.lifecycle") -- needs delivery, combinator
require("scripts.node.stop.layout.base")
require("scripts.node.stop.layout.equipment")
require("scripts.node.stop.layout.pattern")
require("scripts.node.stop.allow")
require("scripts.node.stop.capacity")

require("scripts.vehicle.base")
require("scripts.vehicle.train.base")
require("scripts.vehicle.train.lifecycle")
require("scripts.vehicle.train.layout")

require("scripts.logistics.delivery.train") -- needs inventory, trainstop, train

require("scripts.combinator.modes.station")
require("scripts.combinator.modes.allow")
require("scripts.combinator.modes.dt")
require("scripts.combinator.modes.manifest")
require("scripts.combinator.modes.wagon")
require("scripts.combinator.modes.inventory")
require("scripts.combinator.modes.shared-inventory")
require("scripts.combinator.modes.deliveries")
require("scripts.combinator.modes.surface")

require("scripts.logistics.thread.base")
require("scripts.logistics.thread.enum-nodes")
require("scripts.logistics.thread.poll-nodes")
require("scripts.logistics.thread.logistics")

require("scripts.view.view")
require("scripts.view.net-inventory")

require("scripts.debug.base")
require("scripts.debug.overlay")
require("scripts.debug.debugger")

require("scripts.api.base")
require("scripts.api.query")
require("scripts.api.queries.meta")
require("scripts.api.queries.objects")
require("scripts.api.view")

remote.add_interface("cybersyn2", _G.cs2.remote_api)

require("scripts.commands")

-- Main should run last.
require("scripts.main")

-- Enable support for the Global Variable Viewer debugging mod, if it is
-- installed.
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
