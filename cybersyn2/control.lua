require("scripts.types")
require("scripts.constants")
require("scripts.events")
require("scripts.global")
require("scripts.settings")

require("scripts.combinator.base")
require("scripts.combinator.paste-blueprint")

require("scripts.vehicle.train.base")
require("scripts.vehicle.train.lifecycle")

require("scripts.node.stop.base")
require("scripts.node.stop.layout.equipment")

-- Main should run last.
require("scripts.main")

-- Enable support for the Global Variable Viewer debugging mod, if it is
-- installed.
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
