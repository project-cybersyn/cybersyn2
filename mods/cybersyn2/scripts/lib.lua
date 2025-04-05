local mlib = require("__cybersyn2__.lib.math")

local distsq = mlib.pos_distsq
local INF = math.huge

local DIFFERENT_SURFACE_DISTANCE = 1000000000

---Return the distance-squared between the map positions of the given two
---entities. Returns a large distance if they are on different surfaces.
---@param e1 LuaEntity
---@param e2 LuaEntity
function _G.cs2.lib.distsq(e1, e2)
	if e1.surface_index ~= e2.surface_index then
		return DIFFERENT_SURFACE_DISTANCE
	end
	return distsq(e1.position, e2.position)
end
