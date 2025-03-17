--------------------------------------------------------------------------------
-- Public Cybersyn types and enums. These types may be exposed to other mods
-- via remote interface/queries, and authors can get the definitions for
-- these types by requiring or linking this file to their IDE.
--------------------------------------------------------------------------------

local lib = {}

---@alias UnitNumber uint A Factorio `unit_number` associated uniquely with a particular `LuaEntity`.

---@alias UnitNumberSet table<UnitNumber, true> A collection of Factorio entities referenced by their `unit_number`.

---@alias Id int Unique id of a Cybersyn object, when that id is not a unit_number.

---@alias IdSet table<int, true> A collection of Cybersyn objects referenced by their `id`.

---@alias PlayerIndex uint A Factorio `player_index` associated uniquely with a particular `LuaPlayer`.

---An opaque reference to EITHER a live combinator OR its ghost.
---@class Cybersyn.Combinator.Ephemeral
---@field public entity? LuaEntity The primary entity of the combinator OR its ghost.

---An opaque reference to a fully realized and built combinator that has been indexed by Cybersyn and tracked in game state.
---@class Cybersyn.Combinator: Cybersyn.Combinator.Ephemeral
---@field public id UnitNumber The unique unit number of the combinator entity.
---@field public node_id? uint The id of the node this combinator is associated with, if any.
---@field public is_being_destroyed true? `true` if the combinator is being removed from state at this time.

---A vehicle managed by Cybersyn.
---@class Cybersyn.Vehicle
---@field public id int Unique id of the vehicle.
---@field public type string The type of the vehicle.
---@field public is_being_destroyed true? `true` if the vehicle is in the process of being removed from game state.

---A train managed by Cybersyn.
---@class Cybersyn.Train: Cybersyn.Vehicle
---@field public type "train"
---@field public lua_train LuaTrain? The most recent LuaTrain object representing this train. Note that this is a cached value and must ALWAYS be checked for validity before use.
---@field public lua_train_id Id? The id of the last known good LuaTrain object. Note that this is a cached value and persists even if the lua_train is expired/invalid.
---@field public group string? Last known group assigned by the train sweep task.
---@field public volatile boolean? `true` if the `LuaTrain` associated to this train is unstable and may be invalidated at any time, eg for a train passing through a space elevator.
---@field public item_slot_capacity uint Number of item slots available across all wagons if known.
---@field public fluid_capacity uint Total fluid capacity of all wagons if known.
---@field public layout_id uint The layout ID of the train.

---Numeric encoding of prototype types of carriages
---@enum Cybersyn.CarriageType
lib.CarriageType = {
	Unknown = 0,
	Locomotive = 1,
	-- CargoWagon also includes `infinity-cargo-wagon`s
	CargoWagon = 2,
	FluidWagon = 3,
	ArtilleryWagon = 4,
}

---A Cybersyn train layout.
---@class Cybersyn.TrainLayout
---@field public id Id Unique id of the layout.
---@field public carriage_names string[] The names of the entity prototypes of the train's carriages from front to back.
---@field public carriage_types Cybersyn.CarriageType[] The types of the entity prototypes of the train's carriages from front to back.
---@field public bidirectional boolean `true` if the train has locomotives allowing it to move both directions.

---A reference to a node (station/stop/destination for vehicles) managed by Cybersyn.
---@class Cybersyn.Node
---@field public id uint Unique id of the node.
---@field public type string The type of the node.
---@field public combinator_set UnitNumberSet Set of combinators associated to this node, by unit number.
---@field public is_being_destroyed true? `true` if the node is in the process of being removed from game state.

---A reference to a train stop managed by Cybersyn.
---@class Cybersyn.TrainStop: Cybersyn.Node
---@field public type "stop"
---@field public entity LuaEntity? The `train-stop` entity for this stop, if it exists.
---@field public entity_id UnitNumber? The unit number of the `train-stop` entity for this stop, if it exists.
---@field public allowed_layouts IdSet? Set of accepted train layout IDs. If `nil`, all layouts are allowed.
---@field public allowed_groups table<string, true>? Set of accepted train group names. If `nil`, all groups are allowed.

---Information about the physical shape of a train stop and its associated
---rails and equipment.
---@class (exact) Cybersyn.TrainStopLayout
---@field public node_id Id The id of the node this layout is for.
---@field public cargo_loader_map {[UnitNumber]: uint} Map of equipment that can load cargo to tile indices relative to the train stop.
---@field public fluid_loader_map {[UnitNumber]: uint} Map of equipment that can load fluid to tile indices relative to the train stop.
---@field public carriage_loading_pattern (0|1|2|3)[] Auto-allowlist car pattern, inferred from equipment. 0 = no equipment, 1 = cargo, 2 = fluid, 3 = both. Assumes 6-1 wagons.
---@field public bbox BoundingBox? The bounding box used when scanning for equipment.
---@field public rail_bbox BoundingBox? The bounding box for only the rails.
---@field public rail_set UnitNumberSet The set of rails associated to this stop.
---@field public direction defines.direction? Direction of the vector pointing from the stop entity towards the oncoming track, if known.

---A Cybersyn train group.
---@class Cybersyn.TrainGroup
---@field public name string The factorio train group name.
---@field public trains IdSet The set of vehicle ids of trains in the group.

return lib
