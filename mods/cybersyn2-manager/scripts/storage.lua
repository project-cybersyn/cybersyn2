---@class Cybersyn.Manager.Storage
---@field public players table<PlayerIndex, Cybersyn.Manager.PlayerStorage>
storage = {}

---@class Cybersyn.Manager.PlayerStorage
---@field public inspector? Cybersyn.Manager.InspectorState If open, state of the player's Inspector.

---@class Cybersyn.Manager.InspectorState
---@field public entries Cybersyn.Manager.InspectorEntry[] Open subwindows in the Inspector.

---@class Cybersyn.Manager.InspectorEntry
---@field public type string Type of widget for panel.

_G.mgr.on_init(function()
	storage.players = {}
end)
