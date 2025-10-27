-- Manager globals
_G.mgr = {}

require("scripts.storage")
require("scripts.settings")
require("scripts.elements")

require("scripts.manager.base")

require("scripts.inspector.base")
require("scripts.inspector.inventory")
require("scripts.inspector.train")

require("scripts.main")

-- Enable support for the Global Variable Viewer debugging mod, if it is
-- installed.
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
