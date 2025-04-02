---@class Cybersyn.Manager.Storage
---@field public players table<PlayerIndex, Cybersyn.Manager.PlayerStorage>
---@field public inspector_root table<PlayerIndex, Relm.RootId>
storage = {}

---@class Cybersyn.Manager.PlayerStorage

_G.mgr.on_init(function()
	storage.players = {}
	storage.inspector_root = {}
end)
