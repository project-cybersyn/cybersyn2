-- Internal Cybersyn types and enums.

require("__cybersyn2__.lib.types")

---@class (exact) Cybersyn.PlayerState Per-player global state.
---@field public player_index int The player index of the player whose UI is open.
---@field public open_combinator? Cybersyn.Combinator.Ephemeral The combinator OR ghost currently open in the player's UI, if any.
---@field public open_combinator_unit_number? UnitNumber The unit number of the combinator currently open in the player's UI, if any. This is stored separately to allow for cases where the combinator is removed while the UI is open, eg ghost revival.
