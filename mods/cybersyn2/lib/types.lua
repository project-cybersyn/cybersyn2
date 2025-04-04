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
---@field public mode? string The mode value set on this combinator, if known. Cached for performance reasons.
---@field public inputs? SignalCounts The most recent signals read from the combinator. This will be `nil` if the combinator has not been polled yet or if it is being destroyed. This is a cached value.
---@field public inputs_volatile? boolean `true` if a vehicle was at the station making a delivery when inputs were being read, therefore making them suspect.

---A vehicle managed by Cybersyn.
---@class Cybersyn.Vehicle
---@field public id int Unique id of the vehicle.
---@field public topology_id int Topology this vehicle can service
---@field public type string The type of the vehicle.
---@field public is_being_destroyed true? `true` if the vehicle is in the process of being removed from game state.
---@field public delivery_id Id? The current delivery this vehicle is processing.

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

---@enum Cybersyn.Node.NetworkOperation
lib.NodeNetworkOperation = {
	Any = 1,
	All = 2,
}

---An isolated group of `Node`s that can only communicate with each other.
---@class Cybersyn.Topology
---@field public id Id Unique id of the topology.
---@field public surface_index? uint The index of the surface this topology is associated with, if any. This is not a 1-1 association; a surface may have multiple topologies.
---@field public name? string The name of the topology, if any. This is not a unique key and primarily used for debugging.
---@field public vehicle_type string The vehicle type intended to traverse this topology.

---A reference to a node (station/stop/destination for vehicles) managed by Cybersyn.
---@class Cybersyn.Node
---@field public id Id Unique id of the node.
---@field public topology_id Id Id of the topology this node belongs to.
---@field public type string The type of the node.
---@field public combinator_set UnitNumberSet Set of combinators associated to this node, by unit number.
---@field public created_tick uint Tick number when this node was created.
---@field public is_being_destroyed true? `true` if the node is in the process of being removed from game state.
---@field public inventory_id Id? Inventory of this node. This is what the logistics algorithm uses to determine node contents.
---@field public created_inventory_id Id? The id of the inventory automatically created for this node if any.
---@field public is_producer boolean? `true` if the node can send deliveries
---@field public is_consumer boolean? `true` if the node can receive deliveries
---@field public networks? SignalCounts The network masks of the node. Updated only when the node is polled.
---@field public network_operation Cybersyn.Node.NetworkOperation How the network masks of the node should be combined.
---@field public priority int? Priority of the node.
---@field public priorities SignalCounts? Per-item priorities.
---@field public channel int? Default channel of the node.
---@field public channels SignalCounts? Per-item channels.
---@field public threshold_item_in uint? General inbound item threshold
---@field public threshold_fluid_in uint? General inbound fluid threshold
---@field public threshold_item_out uint? General outbound item threshold
---@field public threshold_fluid_out uint? General outbound fluid threshold
---@field public thresholds_in SignalCounts? Per-item inbound thresholds
---@field public thresholds_out SignalCounts? Per-item outbound thresholds

---A reference to a train stop managed by Cybersyn.
---@class Cybersyn.TrainStop: Cybersyn.Node
---@field public type "stop"
---@field public entity LuaEntity? The `train-stop` entity for this stop, if it exists.
---@field public entity_id UnitNumber? The unit number of the `train-stop` entity for this stop, if it exists.
---@field public allowed_layouts IdSet? Set of accepted train layout IDs. If `nil`, all layouts are allowed.
---@field public allowed_groups table<string, true>? Set of accepted train group names. If `nil`, all groups are allowed.
---@field public dropoffs IdSet Deliveries scheduled to be dropped off at this node.
---@field public pickups IdSet Deliveries scheduled to be picked up from this node.

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

---@class Cybersyn.TrainGroup
---@field public name string The factorio train group name.
---@field public trains IdSet The set of vehicle ids of trains in the group.

---@class Cybersyn.Inventory
---@field public id Id
---@field public surface_index Id? The index of the surface this inventory should be associated with if any.
---@field public created_for_node_id Id? If this inventory was created implicitly for a node, that node's id.
---@field public produce SignalCounts Positive contents of inventory at last poll.
---@field public consume SignalCounts Negative contents of inventory at last poll.
---@field public flow SignalCounts? The net of all future incoming and outgoing deliveries to this inventory. Positive values represent inflows, negative outflows.
---@field public net_produce SignalCounts? Provide net of outflow, cached. Pessimistically excludes inflows.
---@field public net_consume SignalCounts? Request net of infflow, cached.
---@field public deliveries IdSet? The set of future deliveries targeting this inventory.

---@enum Cybersyn.Delivery.State
lib.DeliveryState = {
	Initializing = 1,
	ToSource = 2,
	Loading = 3,
	ToDestination = 4,
	Unloading = 5,
	Completed = 100,
	Failed = 200,
}

---@class Cybersyn.Delivery
---@field public id Id
---@field public created_tick uint The tick this delivery was created.
---@field public state_tick uint The tick this delivery entered its current state.
---@field public state Cybersyn.Delivery.State The current state of the delivery.
---@field public is_changing_state boolean? `true` if the delivery is in the process of changing state.
---@field public queued_state_changes Cybersyn.Delivery.State[]? Reentrant state changes are not allowed; queue them here.
---@field public vehicle_id Id The id of the vehicle this delivery is assigned to.
---@field public source_id Id The id of the node this delivery is from.
---@field public destination_id Id The id of the node this delivery is to.
---@field public source_inventory_id Id The id of the inventory this delivery is from, if any.
---@field public destination_inventory_id Id The id of the inventory this delivery is to, if any.
---@field public manifest SignalCounts The intended contents of the delivery.

--------------------------------------------------------------------------------
-- Public type encodings for the query interface.
--------------------------------------------------------------------------------

---Self-describing list of public primitive data types. (Primitive in this sense
---means Cybersyn won't split it into further pieces, not that it is a Lua
---primitive.)
---@enum Cybersyn.PrimitiveType
local PrimitiveType = {
	"boolean",
	"int",
	"number",
	"string",
	"SignalKey",
	"UnitNumber",
	"Id",
	"Cybersyn.Combinator",
	"Cybersyn.Vehicle",
	"Cybersyn.Train",
	"Cybersyn.Node",
	"Cybersyn.TrainStop",
	"Cybersyn.TrainGroup",
	"SurfaceIndex",
	"ProductSignalKey",
	"VirtualSignalKey",
	"EnumValues",
	"Cybersyn.QueryDef",
	"Nil",
	"Cybersyn.Inventory",
	["boolean"] = 1,
	["int"] = 2,
	["number"] = 3,
	["string"] = 4,
	["SignalKey"] = 5,
	["UnitNumber"] = 6,
	["Id"] = 7,
	["Cybersyn.Combinator"] = 8,
	["Cybersyn.Vehicle"] = 9,
	["Cybersyn.Train"] = 10,
	["Cybersyn.Node"] = 11,
	["Cybersyn.TrainStop"] = 12,
	["Cybersyn.TrainGroup"] = 13,
	["SurfaceIndex"] = 14,
	["ProductSignalKey"] = 15,
	["VirtualSignalKey"] = 16,
	["EnumValues"] = 17,
	["Cybersyn.QueryDef"] = 18,
	["Nil"] = 19,
	["Cybersyn.Inventory"] = 20,
}
lib.PrimitiveType = PrimitiveType

---Species of non-primitive container that can contain items of a `Cybersyn.DataType`.
---@enum Cybersyn.ContainerType
local ContainerType = {
	"value",
	"list",
	"set",
	"map",
	"enum",
	["value"] = 1,
	["list"] = 2,
	["set"] = 3,
	["map"] = 4,
	["enum"] = 5,
}
lib.ContainerType = ContainerType

---Machine readable description of a data type. Fields:
--- * `is_required` - `true` if the corresponding data is required
--- * `container_type` - The type of container this data is in.
--- * `primary_type` - Primary type of container elements; key type for maps.
--- * `subtype` - Subtype of the data. Value type for maps, enum name for enums.
---@alias Cybersyn.DataType [boolean, Cybersyn.ContainerType, Cybersyn.PrimitiveType, Cybersyn.PrimitiveType|string|int|nil]

return lib
