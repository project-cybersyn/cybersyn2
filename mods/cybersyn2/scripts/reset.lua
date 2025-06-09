--------------------------------------------------------------------------------
-- Reset command.
-- Destroys all CS internal data and attempts to rebuild it from world state.
--------------------------------------------------------------------------------

local cs2 = _G.cs2

---@class Cybersyn.ResetData
---@field public combinator_settings_cache? table<UnitNumber, Tags> On reset, combinator settings must be handed off.
---@field public inventory_links? Cybersyn.Internal.StoredLink[] On reset, inventory links must be handed off.
---@field public reasons? string[] On attempted reset, reasons the reset should not proceed. If `nil` or empty, the reset will proceed.

function _G.cs2.try_reset()
	local try_reset_state = { reasons = {} }
	cs2.raise_try_reset(try_reset_state)
	if try_reset_state.reasons and #try_reset_state.reasons > 0 then
		local reasons = table.concat(try_reset_state.reasons, "\n")
		game.print({
			"",
			"/cs2-reset failed. Reasons:\n",
			reasons,
			"\nResolve these issues and then reset again.\nUse /cs2-force-reset to reset anyway.",
		})
		return
	end
	cs2.reset()
end

function _G.cs2.reset()
	local reset_state = {}
	local nodes_before = table_size(storage.nodes)
	cs2.raise_reset(reset_state)
	cs2.raise_startup(reset_state)
	local nodes_after = table_size(storage.nodes)
	game.print({
		"",
		"Cybersyn 2 reset complete. ",
		nodes_before,
		" nodes before reset, ",
		nodes_after,
		" nodes after.",
	})
end
