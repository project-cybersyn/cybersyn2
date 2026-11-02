--------------------------------------------------------------------------------
-- Reset command.
-- Destroys all CS internal data and attempts to rebuild it from world state.
--------------------------------------------------------------------------------

local cs2 = _G.cs2
local events = require("lib.core.event")
local strace = require("lib.core.strace")
local tlib = require("lib.core.table")

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

local pairs = pairs

---Shuts down Cybersyn 2.
---@param force boolean If `true`, forces shutdown even if there are vetoes.
function cs2.shutdown(force)
	---@type Core.ResetData
	local try_shutdown_state =
		{ init = false, handoff = false, veto_shutdown = {} }
	strace.info("invoking on_try_shutdown")
	events.raise("on_try_shutdown", try_shutdown_state)
	local veto_shutdown = try_shutdown_state.veto_shutdown
	if (not force) and veto_shutdown and #veto_shutdown > 0 then
		table.insert(veto_shutdown, 1, "")
		-- XXX: TYPES: FMTK type union bug (LocalisedString)
		---@diagnostic disable-next-line: param-type-mismatch
		game.print({ "cybersyn2-commands.shutdown-vetoed", veto_shutdown })
		return
	end
	if not force and storage._SHUTDOWN_DATA then
		game.print({ "cybersyn2-commands.shutdown-already-shut-down" })
		return
	end

	-- Perform shutdown
	---@type Core.ResetData
	local shutdown_state = { init = false, handoff = false }
	strace.info("invoking on_shutdown")
	events.raise("on_shutdown", shutdown_state)

	-- Destroy storage
	__clear_storage()
	storage._SHUTDOWN_DATA = shutdown_state

	-- Destroy lingering render objects. (this resolves a bug in some
	-- previous versions of cs2.)
	local objs = rendering.get_all_objects("cybersyn2")
	for _, o in pairs(objs) do
		o.destroy()
	end

	game.print({ "cybersyn2-commands.shutdown-complete" })
end

---Restarts Cybersyn 2 after a shutdown.
function cs2.restart()
	if not storage._SHUTDOWN_DATA then
		game.print({ "cybersyn2-commands.restart-not-shut-down" })
		return
	end
	local shutdown_data = storage._SHUTDOWN_DATA
	storage._SHUTDOWN_DATA = nil

	strace.info("invoking on_startup")
	shutdown_data.init = false
	shutdown_data.handoff = true
	events.raise("on_startup", shutdown_data)
	game.print({ "cybersyn2-commands.restart-complete" })
end
