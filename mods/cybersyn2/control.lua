-- Unique global table to avoid polluting `_G`.
--
-- Whenever setting a global, always use `_G.cs2.x.y = ...`
-- as sumneko code completion gets confused otherwise.
_G.cs2 = {
	remote_api = {},
	gui = {},
	lib = {},
	---Debug APIs, do not use.
	debug = {},
}

require("scripts.types")
require("scripts.constants")
require("scripts.events")
require("scripts.storage")
require("scripts.settings")
require("scripts.lib")
require("scripts.threads")

require("scripts.logistics.inventory.base")
require("scripts.logistics.delivery.base")

require("scripts.combinator.base")
require("scripts.combinator.setting")
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

require("scripts.combinator.state") -- needs inventory, node

require("scripts.vehicle.base")
require("scripts.vehicle.train.base")
require("scripts.vehicle.train.lifecycle")
require("scripts.vehicle.train.layout")

require("scripts.logistics.delivery.train") -- needs inventory, trainstop, train

require("scripts.combinator.modes.station.base")
require("scripts.combinator.modes.station.impl")
require("scripts.combinator.modes.allow.base")
require("scripts.combinator.modes.allow.impl")
require("scripts.combinator.modes.dt.base")
require("scripts.combinator.modes.pusht.base")
require("scripts.combinator.modes.sinkt.base")
require("scripts.combinator.modes.channels.base")
require("scripts.combinator.modes.dump.base")
require("scripts.combinator.modes.manifest.base")
require("scripts.combinator.modes.wagon")

require("scripts.logistics.thread.base")
require("scripts.logistics.thread.poll-combinators")
require("scripts.logistics.thread.next-t")
require("scripts.logistics.thread.poll-nodes")
require("scripts.logistics.thread.alloc")
require("scripts.logistics.thread.find-vehicles")
require("scripts.logistics.thread.route")

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
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
