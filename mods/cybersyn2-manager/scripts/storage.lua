---@class Cybersyn.Manager.Storage
---@field public players table<PlayerIndex, Cybersyn.Manager.PlayerStorage>
storage = {}

---@class Cybersyn.Manager.PlayerStorage
---@field public inspector_root_id? Relm.RootId Relm root of the player's inspector.

---@class Cybersyn.Manager.InspectorState
---@field public entries Cybersyn.Manager.InspectorEntry[] Open subwindows in the Inspector.

---@class Cybersyn.Manager.InspectorEntry
---@field public type string Type of widget for panel.

_G.mgr.on_init(function() storage.players = {} end)
