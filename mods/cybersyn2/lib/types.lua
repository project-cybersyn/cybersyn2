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

---@alias SignalKey string A string identifying a particular SignalID.

---@alias SignalCounts table<SignalKey, int> Signals and associated counts.

---@alias SignalSet table<SignalKey, true> A collection of signals referenced by their `SignalKey`.

---@alias Cybersyn.Manifest SignalCounts

---@class StateMachine
---@field public state string Current state.
---@field public is_changing_state boolean? `true` if a state change is ongoing
---@field public queued_state_changes string[]? A queue of state changes to be applied

---An opaque reference to EITHER a live combinator OR its ghost.
---@class Cybersyn.Combinator.Ephemeral
---@field public entity? LuaEntity The primary entity of the combinator OR its ghost.

---An opaque reference to a fully realized and built combinator that has been indexed by Cybersyn and tracked in game state.
---@class Cybersyn.Combinator: Cybersyn.Combinator.Ephemeral
---@field public id UnitNumber The unique unit number of the combinator entity.
---@field public node_id? uint The id of the node this combinator is associated with, if any.
---@field public is_being_destroyed true? `true` if the combinator is being removed from state at this time.
---@field public mode? string The mode value set on this combinator, if known. Cached for performance reasons.
---@field public inputs? SignalCounts The most recent signals read from the combinator. This is a cached value and will be `nil` in various situations where the combinator hasn't been or can't be read.
---@field public red_inputs? SignalCounts As `inputs` but for only the red wire. Exists only for modes with `independent_input_wires` set.
---@field public green_inputs? SignalCounts As `inputs` but for only the green wire. Exists only for modes with `independent_input_wires` set.
---@field public last_read_tick uint The tick this combinator was last read.
---@field public associated_entities table<string, LuaEntity>? Hidden or related entities that must be created or destroyed along with the combinator.
---@field public connected_rail LuaEntity? If this combinator was built next to a rail, this is that rail.

---A vehicle managed by Cybersyn.
---@class Cybersyn.Vehicle
---@field public id int Unique id of the vehicle.
---@field public topology_id int? Topology this vehicle can service
---@field public type string The type of the vehicle.
---@field public is_being_destroyed true? `true` if the vehicle is in the process of being removed from game state.
---@field public delivery_id Id? The current delivery this vehicle is processing.
---@field public created_tick uint The tick this vehicle was created.

---A train managed by Cybersyn.
---@class Cybersyn.Train: Cybersyn.Vehicle
---@field public type "train"
---@field public lua_train LuaTrain? The most recent LuaTrain object representing this train. Note that this is a cached value and must ALWAYS be checked for validity before use.
---@field public lua_train_id Id? The id of the last known good LuaTrain object. Note that this is a cached value and persists even if the lua_train is expired/invalid.
---@field public home_surface_index Id The index of the surface this train was created on.
---@field public stock LuaEntity? A rolling-stock entity for this train.
---@field public group string? Last known group assigned by the train sweep task.
---@field public volatile boolean? `true` if the `LuaTrain` associated to this train is unstable and may be invalidated at any time, eg for a train passing through a space elevator.
---@field public item_slot_capacity uint Number of item slots available across all wagons if known.
---@field public fluid_capacity uint Total fluid capacity of all wagons if known.
---@field public per_wagon_item_slot_capacity table<uint, uint>? Cached number of item slots per wagon. Used by wagon control. Cleared on capacity re-eval.
---@field public per_wagon_fluid_capacity table<uint, uint>? Cached fluid capacity per wagon. Used by wagon control. Cleared on capacity re-eval.
---@field public layout_id uint The layout ID of the train.
---@field public stopped_at LuaEntity? Cache of last known train stop. This value should be treated as volatile.
---@field public is_filtered boolean? `true` if wagon filters were set on this train upon arrival at a stop. Causes filters to be cleared when train leaves.

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
---@field public n_cargo_wagons uint Number of cargo wagons in the train.
---@field public n_fluid_wagons uint Number of fluid wagons in the train.
---@field public min_item_slot_capacity? uint Minimum item slot capacity of all trains matching this layout, if known.
---@field public min_fluid_capacity? uint Minimum fluid capacity of all trains matching this layout, if known.

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
---@field public thread_id? int The id of the thread servicing this topology if any.
---@field public vehicle_type string The vehicle type intended to traverse this topology.
---@field public provided? SignalCounts Count of all items provided by nodes in this topology. This is a cached value and is not updated in realtime.
---@field public requested? SignalCounts Count of all items requested by nodes in this topology. This is a cached value and is not updated in realtime.
---@field public global_combinators IdSet Set of global combinators (e.g. inventory combinators) associated with this topology. This DOES NOT include per-node combinators.

---A reference to a node (station/stop/destination for vehicles) managed by Cybersyn.
---@class Cybersyn.Node
---@field public id Id Unique id of the node.
---@field public topology_id Id? Id of the topology this node belongs to.
---@field public type string The type of the node.
---@field public combinator_set UnitNumberSet Set of combinators associated to this node, by unit number.
---@field public created_tick uint Tick number when this node was created.
---@field public is_being_destroyed true? `true` if the node is in the process of being removed from game state.
---@field public inventory_id Id? Inventory of this node. This is what the logistics algorithm uses to determine node contents.
---@field public created_inventory_id Id? The id of the inventory automatically created for this node if any.
---@field public deliveries IdSet Set of all active deliveries involving this node, both inbound and outbound.
---@field public is_producer boolean? `true` if the node can send deliveries
---@field public is_consumer boolean? `true` if the node can receive deliveries
---@field public priority int? Default priority of the node.
---@field public default_networks SignalCounts? Default item networks of the node.
---@field public threshold_item_in uint? General inbound item threshold
---@field public threshold_fluid_in uint? General inbound fluid threshold
---@field public threshold_item_out uint? General outbound item threshold
---@field public threshold_fluid_out uint? General outbound fluid threshold
---@field public threshold_auto_item_max? uint Maximum item threshold for auto-thresholding (stacks)
---@field public threshold_auto_fluid_max? uint Maximum fluid threshold for auto-thresholding
---@field public thresholds_in SignalCounts? Per-item inbound thresholds
---@field public thresholds_out SignalCounts? Per-item outbound thresholds
---@field public stack_thresholds boolean? `true` if item thresholds should be interpreted as stacks
---@field public last_consumed_tick SignalCounts The last tick a delivery of the given item was scheduled to this node.
---@field public disable_auto_thresholds boolean? `true` if the node should not automatically set thresholds based on its requests.
---@field public auto_threshold_fraction? number Fraction of requests to use for auto-thresholding.

---A reference to a train stop managed by Cybersyn.
---@class Cybersyn.TrainStop: Cybersyn.Node
---@field public type "stop"
---@field public entity LuaEntity? The `train-stop` entity for this stop, if it exists.
---@field public entity_id UnitNumber? The unit number of the `train-stop` entity for this stop, if it exists.
---@field public allowed_layouts IdSet? Set of accepted train layout IDs. If `nil`, all layouts are allowed.
---@field public allowed_groups table<string, true>? Set of accepted train group names. If `nil`, all groups are allowed.
---@field public delivery_queue Id[] All deliveries currently enroute for this stop, in order. The lowest index in the queue is the next delivery to be processed.
---@field public allow_departure_signal SignalID? The signal key that will allow a train to depart this stop.
---@field public force_departure_signal SignalID? The signal key that will force a train to depart this stop.
---@field public inactivity_timeout uint? The number of ticks for the inactivity timeout
---@field public inactivity_mode "deliver"|"forceout"|nil How to apply inactivity timeouts
---@field public disable_cargo_condition boolean? `true` if the cargo condition should be ignored
---@field public produce_single_item boolean? `true` if the station should only provide single items per delivery
---@field public reserved_slots uint? Reserved slots per cargo wagon
---@field public reserved_capacity uint? Reserved capacity per fluid wagon
---@field public spillover uint? Spillover per item per cargo wagon
---@field public ignore_secondary_thresholds boolean? `true` if station should ignore thresholds when adding secondary items to outgoing trains.
---@field public per_wagon_mode boolean? `true` if the station is in per-wagon mode due to the presence of a wagon comb.
---@field public shared_inventory_slaves IdSet? Exists only if this station is a shared-inventory master and contains the ids of the slaves.
---@field public shared_inventory_master Id? The id of the shared inventory master, if this station is a slave.

---Information about the physical shape of a train stop and its associated
---rails and equipment.
---@class Cybersyn.TrainStopLayout
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

---@class Cybersyn.Order
---@field public inventory Cybersyn.Inventory The inventory against which this order is placed.
---@field public node_id Id The id of the node this order will deliver to/from
---@field public combinator_id? Id The id of the governing combinator that created this order if it exists.
---@field public combinator_input? "red"|"green" Input wire this order was read from on its governing combinator.
---@field public requests SignalCounts The requested items for this order.
---@field public provides SignalCounts The provided items for this order.
---@field public thresholds_in SignalCounts Inbound thresholds for this order.
---@field public thresholds_out SignalCounts Outbound thresholds for this order.
---@field public networks SignalCounts The computed network masks of this order.
---@field public last_consumed_tick SignalCounts Last consumed ticks for the order's associated inventory.
---@field public priority int The computed priority of this order.
---@field public request_all_items boolean? `true` if this order should request all items in the network.
---@field public request_all_fluids boolean? `true` if this order should request all fluids in the network.
---@field public busy_value number Cached value computed at poll time regarding how busy the associated node is.

---@class Cybersyn.Inventory
---@field public id Id
---@field public topology_id? Id The id of the topology this inventory is associated with, if known.
---@field public created_for_node_id? Id If this inventory was created implicitly for a node, that node's id.
---@field public inventory SignalCounts True full contents of the inventory.
---@field public orders Cybersyn.Order[] The orders associated with this inventory.
---@field public inflow SignalCounts Future incoming cargo
---@field public outflow SignalCounts Future outgoing cargo
---@field public item_stack_capacity? uint The number of item slots available in this inventory, if known.
---@field public fluid_capacity? uint The total fluid capacity of this inventory, if known.

---@class Cybersyn.Delivery: StateMachine
---@field public id Id
---@field public type string
---@field public is_being_destroyed true? `true` if the delivery is in the process of being removed from game state.
---@field public created_tick uint The tick this delivery was created.
---@field public state_tick uint The tick this delivery entered its current state.
---@field public vehicle_id Id The id of the vehicle this delivery is assigned to.
---@field public from_id Id The id of the node this delivery is from.
---@field public to_id Id The id of the node this delivery is to.
---@field public from_inventory_id Id The id of the inventory this delivery is from, if any.
---@field public to_inventory_id Id The id of the inventory this delivery is to, if any.
---@field public manifest SignalCounts The intended contents of the delivery.

---@class Cybersyn.TrainDelivery: Cybersyn.Delivery
---@field public from_charge SignalCounts? Amount charged against the source station's inventory, which may differ from the manifest by spillover.
---@field public to_charge SignalCounts? Amount charged towards the destination station's inventory. Equal to the manifest, but `nil`ed when charge is cleared.
---@field public spillover uint Spillover used when calculating this delivery
---@field public reserved_slots uint Reserved slots used when calculating this delivery
---@field public reserved_fluid_capacity uint Reserved capacity used when calculating this delivery

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
	"Cybersyn.Topology",
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
	["Cybersyn.Topology"] = 21,
}
lib.PrimitiveType = PrimitiveType

---Species of non-primitive container that can contain items of a `Cybersyn.PrimitiveType`.
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
