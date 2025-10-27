local events = require("__cybersyn2__.lib.core.event")

---@class Cybersyn.Manager.Storage
---@field public players table<PlayerIndex, Cybersyn.Manager.PlayerStorage>
---@field public inspector_root table<PlayerIndex, Relm.RootId>
---@field public manager_root table<PlayerIndex, Relm.RootId>
storage = {}

---@class Cybersyn.Manager.PlayerStorage

events.bind("on_startup", function()
	storage.players = {}
	storage.inspector_root = {}
	storage.manager_root = {}
end)
