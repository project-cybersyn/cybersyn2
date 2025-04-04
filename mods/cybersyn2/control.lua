-- Unique global table to avoid polluting `_G`.
-- Root level global tables should be declared in `control.lua` to avoid
-- include order dependencies.
--
-- Whenever setting a global, always use `_G.cs2.x.y = ...`
-- as sumneko code completion gets confused otherwise.
_G.cs2 = {
	remote_api = {},
	threads_api = {},
	node_api = {},
	stop_api = {},
	combinator_api = {},
	delivery_api = {},
	inventory_api = {},
	train_api = {},
}

require("scripts.types")
require("scripts.constants")
require("scripts.events")
require("scripts.storage")
require("scripts.settings")

require("scripts.threads")

require("scripts.combinator.base")
require("scripts.combinator.mode")
require("scripts.combinator.setting")
require("scripts.combinator.lifecycle")
require("scripts.combinator.gui.base")

require("scripts.combinator.modes.station.base")
require("scripts.combinator.modes.station.impl")
require("scripts.combinator.modes.allow.base")
require("scripts.combinator.modes.allow.impl")

require("scripts.vehicle.train.base")
require("scripts.vehicle.train.lifecycle")
require("scripts.vehicle.train.layout")

require("scripts.node.base")
require("scripts.node.lifecycle")
require("scripts.node.stop.base")
require("scripts.node.stop.lifecycle")
require("scripts.node.stop.layout.base")
require("scripts.node.stop.layout.equipment")
require("scripts.node.stop.layout.pattern")

require("scripts.logistics.inventory.base")

require("scripts.logistics.delivery.base")

require("scripts.logistics.thread.base")
require("scripts.logistics.thread.init")
require("scripts.logistics.thread.poll-inventories")
require("scripts.logistics.thread.poll-nodes")
require("scripts.logistics.thread.create-deliveries")

require("scripts.debug.base")
require("scripts.debug.overlay")

require("scripts.api.base")
require("scripts.api.query")
require("scripts.api.queries.meta")
require("scripts.api.queries.objects")

remote.add_interface("cybersyn2", _G.cs2.remote_api)

-- Main should run last.
require("scripts.main")

-- Enable support for the Global Variable Viewer debugging mod, if it is
-- installed.
if script.active_mods["gvv"] then
	require("__gvv__.gvv")()
end
