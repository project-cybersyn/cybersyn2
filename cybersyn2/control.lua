require("scripts.types")
require("scripts.constants")
require("scripts.events")
require("scripts.storage")
require("scripts.settings")

require("scripts.combinator.base")
require("scripts.combinator.mode")
require("scripts.combinator.setting")
require("scripts.combinator.lifecycle")
require("scripts.combinator.gui.base")

require("scripts.combinator.modes.station")
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

require("scripts.debug.base")
require("scripts.debug.overlay")

-- Main should run last.
require("scripts.main")

-- Enable support for the Global Variable Viewer debugging mod, if it is
-- installed.
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
