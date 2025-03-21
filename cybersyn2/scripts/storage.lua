--------------------------------------------------------------------------------
-- Type definition and implementation of Cybersyn's game state storage.
--------------------------------------------------------------------------------

---The entire synchronized game state for Cybersyn.
---@class (exact) Cybersyn.Storage
---@field public players table<PlayerIndex, Cybersyn.PlayerState> Per-player state
---@field public vehicles table<Id, Cybersyn.Vehicle> All Cybersyn vehicles indexed by id
---@field public combinators table<UnitNumber, Cybersyn.Combinator.Internal> All Cybersyn combinators indexed by unit number
---@field public nodes table<Id, Cybersyn.Node> All Cybersyn nodes indexed by id
---@field public inventories table<Id, Cybersyn.Inventory> All Cybersyn inventories indexed by id
---@field public deliveries table<Id, Cybersyn.Delivery> All Cybersyn deliveries indexed by id
---@field public task_ids table<string, Scheduler.TaskId> Ids of core tasks
---@field public train_groups table<string, Cybersyn.TrainGroup> All Cybersyn-controlled train groups indexed by Factorio group name
---@field public luatrain_id_to_vehicle_id table<Id, Id> Map of LuaTrain ids to Cybersyn vehicle ids
---@field public rail_id_to_node_id table<UnitNumber, Id> Map of rail unit numbers to node ids of the associated train stop
---@field public combinator_settings_cache table<UnitNumber, Tags> Cache used to store combinator settings so that it is not necessary to read encoded data from the combinator's entity
---@field public stop_id_to_node_id table<UnitNumber, Id> Map from UnitNumbers of `train-stop` entities to the corresponding node id
---@field public stop_layouts table<Id, Cybersyn.TrainStopLayout> Layouts of train stops, indexed by node id
---@field public train_layouts table<Id, Cybersyn.TrainLayout> Layouts of trains, indexed by layout id
---@field public debug_state Cybersyn.Internal.DebugState Debug state, should remain empty unless debug mode is enabled for the save
storage = {}

---Per-player global state.
---@class (exact) Cybersyn.PlayerState
---@field public player_index int
---@field public open_combinator? Cybersyn.Combinator.Ephemeral The combinator OR ghost currently open in the player's UI, if any.
---@field public open_combinator_unit_number? UnitNumber The unit number of the combinator currently open in the player's UI, if any. This is stored separately to allow for cases where the combinator is removed while the UI is open, eg ghost revival.

on_init(function()
	storage.players = {}
	storage.vehicles = {}
	storage.combinators = {}
	storage.nodes = {}
	storage.inventories = {}
	storage.deliveries = {}
	storage.task_ids = {}
	storage.train_groups = {}
	storage.luatrain_id_to_vehicle_id = {}
	storage.rail_id_to_node_id = {}
	storage.combinator_settings_cache = {}
	storage.stop_id_to_node_id = {}
	storage.stop_layouts = {}
	storage.train_layouts = {}
	storage.debug_state = {}
end, true)
