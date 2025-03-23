-- Avoid abusing _G because FMTK doesn't understand mod separation of _G.
-- TODO: should probably do this in CS2 also (ugh)

-- Manager globals
_G.mgr = {}

require("scripts.types")
require("scripts.events")
require("scripts.storage")
require("scripts.settings")

require("scripts.inspector.base")
require("scripts.inspector.frames")

require("scripts.main")
