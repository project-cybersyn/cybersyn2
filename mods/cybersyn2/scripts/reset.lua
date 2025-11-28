--------------------------------------------------------------------------------
-- Reset command.
-- Destroys all CS internal data and attempts to rebuild it from world state.
--------------------------------------------------------------------------------

local cs2 = _G.cs2
local events = require("lib.core.event")
local strace = require("lib.core.strace")

---Shuts down Cybersyn 2.
---@param force boolean If `true`, forces shutdown even if there are vetoes.
function _G.cs2.shutdown(force)
	---@type Core.ResetData
	local try_shutdown_state =
		{ init = false, handoff = false, veto_shutdown = {} }
	strace.info("invoking on_try_shutdown")
	events.raise("on_try_shutdown", try_shutdown_state)
	if (not force) and (#try_shutdown_state.veto_shutdown > 0) then
		table.insert(try_shutdown_state.veto_shutdown, 1, "")
		game.print({
			"",
			"/cs2-shutdown failed. Reasons:\n",
			try_shutdown_state.veto_shutdown,
			"\nResolve these issues and then reset again.\nUse `/cs2-shutdown force` to shut down anyway.",
		})
		return
	end
	if not force and storage._SHUTDOWN_DATA then
		game.print(
			"Cybersyn 2 shutdown failed: must restart with `/cs2-restart` before shutting down again. Use `/cs2-shutdown force` to shut down anyway."
		)
		return
	end

	-- Perform shutdown
	---@type Core.ResetData
	local shutdown_state = { init = false, handoff = false }
	strace.info("invoking on_shutdown")
	events.raise("on_shutdown", shutdown_state)
	storage._SHUTDOWN_DATA = shutdown_state

	-- Destroy lingering render objects. (this resolves a bug in some
	-- previous versions of cs2.)
	local objs = rendering.get_all_objects("cybersyn2")
	for _, o in pairs(objs) do
		o.destroy()
	end

	game.print("Cybersyn 2 shutdown complete.")
end

---Restarts Cybersyn 2 after a shutdown.
function _G.cs2.restart()
	if not storage._SHUTDOWN_DATA then
		game.print(
			"Cybersyn 2 restart failed: must shut down with `/cs2-shutdown` first."
		)
		return
	end
	local shutdown_data = storage._SHUTDOWN_DATA
	storage._SHUTDOWN_DATA = nil

	strace.info("invoking on_startup")
	shutdown_data.init = false
	shutdown_data.handoff = true
	events.raise("on_startup", shutdown_data)
	game.print("Cybersyn 2 restart complete.")
end
