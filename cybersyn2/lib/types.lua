-- Public Cybersyn types and enums. These types may be exposed to other mods
-- via remote interface/queries, and authors can get the definitions for
-- these types by requiring or linking this file to their IDE.

---@alias UnitNumber uint A Factorio `unit_number` associated uniquely with a particular `LuaEntity`.

---@alias UnitNumberSet table<UnitNumber, true> A collection of Factorio entities referenced by their `unit_number`.

---@alias Id int Unique id of a Cybersyn object, when that id is not a unit_number.

---@alias IdSet table<int, true> A collection of Cybersyn objects referenced by their `id`.

---@alias PlayerIndex uint A Factorio `player_index` associated uniquely with a particular `LuaPlayer`.

---@class Cybersyn.Combinator.Ephemeral An opaque reference to EITHER a live combinator OR its ghost.
---@field public entity? LuaEntity The primary entity of the combinator OR its ghost.

---@class Cybersyn.Combinator: Cybersyn.Combinator.Ephemeral An opaque reference to a fully realized and built combinator that has been indexed by Cybersyn and tracked in game state.
---@field public id UnitNumber The immutable unit number of the combinator entity.
---@field public node_id? uint The id of the node this combinator is associated with, if any.
---@field public is_being_destroyed true? `true` if the combinator is being removed from state at this time.
---@field public is_proximate true? `true` if the combinator is within the proximity of a train stop.

---@class Cybersyn.Vehicle A vehicle managed by Cybersyn.
---@field public id int Unique id of the vehicle.
---@field public type string The type of the vehicle.
---@field public is_being_destroyed true? `true` if the vehicle is in the process of being removed from game state.

---@class Cybersyn.Train: Cybersyn.Vehicle A train managed by Cybersyn.
---@field public type "train"
---@field public lua_train LuaTrain? The most recent LuaTrain object representing this train. Note that this is a cached value and must ALWAYS be checked for validity before use.
---@field public lua_train_id Id? The id of the last known good LuaTrain object. Note that this is a cached value and persists even if the lua_train is expired/invalid.
---@field public group string? Last known group assigned by the train sweep task.
---@field public volatile boolean? `true` if the `LuaTrain` associated to this train is unstable and may be invalidated at any time, eg for a train passing through a space elevator.

---@class Cybersyn.Node A reference to a node (station/stop/destination for vehicles) managed by Cybersyn.
---@field public id uint Unique id of the node.
---@field public type string The type of the node.

---@class Cybersyn.TrainStop: Cybersyn.Node A reference to a train stop managed by Cybersyn.
---@field public type "train_stop"

---@class Cybersyn.TrainGroup A Cybersyn train group.
---@field public name string The factorio train group name.
---@field public trains IdSet The set of vehicle ids of trains in the group.
