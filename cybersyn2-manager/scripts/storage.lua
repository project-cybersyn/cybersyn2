---@class Cybersyn.Manager.Storage
---@field public players table<PlayerIndex, Cybersyn.Manager.PlayerStorage>

---@class Cybersyn.Manager.PlayerStorage
---@field public inspector? Cybersyn.Manager.InspectorState If open, state of the player's Inspector.

---@class Cybersyn.Manager.InspectorState
---@field public entries Cybersyn.Manager.InspectorEntry[] Open subwindows in the Inspector.

---@class Cybersyn.Manager.InspectorEntry
---@field public query Cybersyn.QueryInput Query that the entry is displaying.
---@field public result Cybersyn.QueryResult Most recent cached query result.
