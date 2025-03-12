-- Public Cybersyn types and enums. These types may be exposed to other mods
-- via remote interface/queries.

---@alias UnitNumber uint A Factorio `unit_number` associated uniquely with a particular `LuaEntity`.

---@alias UnitNumberSet {[UnitNumber]: true} A collection of Factorio entities referenced by their `unit_number`.

---@alias PlayerIndex uint A Factorio `player_index` associated uniquely with a particular `LuaPlayer`.

---@class Cybersyn.Combinator.Ephemeral An opaque reference to EITHER a live combinator OR its ghost.
---@field public entity? LuaEntity The primary entity of the combinator OR its ghost.

---@class Cybersyn.Combinator: Cybersyn.Combinator.Ephemeral An opaque reference to a fully realized and built combinator that has been indexed by Cybersyn and tracked in game state.
---@field public id UnitNumber The immutable unit number of the combinator entity.
---@field public node_id? uint The id of the node this combinator is associated with, if any.
---@field public is_being_destroyed true? `true` if the combinator is being removed from state at this time.
---@field public is_proximate true? `true` if the combinator is within the proximity of a train stop.
