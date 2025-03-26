-- Manager globals
_G.mgr = {}

require("scripts.types")
require("scripts.events")
require("scripts.storage")
require("scripts.settings")

require("scripts.inspector.base")
require("scripts.inspector.frames")

-- XXX: debug
require("scripts.relmtest")

require("scripts.main")

-- Enable support for the Global Variable Viewer debugging mod, if it is
-- installed.
if script.active_mods["gvv"] then
	require("__gvv__.gvv")()
end
