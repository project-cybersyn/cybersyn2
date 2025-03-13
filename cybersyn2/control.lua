require("scripts.types")
require("scripts.constants")
require("scripts.events")
require("scripts.global")
require("scripts.settings")

require("scripts.vehicle.train.base")
require("scripts.vehicle.train.lifecycle")

-- Main must run last.
require("scripts.main")

-- Enable support for the Global Variable Viewer debugging mod, if it is
-- installed.
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
