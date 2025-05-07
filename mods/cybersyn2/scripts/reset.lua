--------------------------------------------------------------------------------
-- Reset command.
-- Destroys all CS internal data and attempts to rebuild it from world state.
--------------------------------------------------------------------------------

local cs2 = _G.cs2

---@class Cybersyn.ResetData
---@field public combinator_settings_cache? table<UnitNumber, Tags> On reset, combinator settings must be handed off.
---@field public inventory_links? Cybersyn.Internal.StoredLink[] On reset, inventory links must be handed off.

function _G.cs2.reset()
	local reset_state = {}
	cs2.raise_reset(reset_state)
	cs2.raise_startup(reset_state)
end
