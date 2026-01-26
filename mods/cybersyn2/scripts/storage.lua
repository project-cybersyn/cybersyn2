--------------------------------------------------------------------------------
-- Type definition and implementation of Cybersyn's game state storage.
--------------------------------------------------------------------------------

local events = require("lib.core.event")

---The entire synchronized game state for Cybersyn.
---@class (exact) Cybersyn.Storage
---@field public players table<PlayerIndex, Cybersyn.PlayerState> Per-player state
---@field public vehicles table<Id, Cybersyn.Vehicle> All Cybersyn vehicles indexed by id
---@field public combinators table<int64, Cybersyn.Combinator> All Cybersyn combinators indexed by Thing ID
---@field public topologies table<Id, Cybersyn.Topology> All Cybersyn topologies indexed by id
---@field public nodes table<Id, Cybersyn.Node> All Cybersyn nodes indexed by id
---@field public inventories table<Id, Cybersyn.Inventory> All Cybersyn inventories indexed by id
---@field public deliveries table<Id, Cybersyn.Delivery> All Cybersyn deliveries indexed by id
---@field public task_ids table<string, Scheduler.TaskId> Ids of core tasks
---@field public train_groups table<string, Cybersyn.Internal.TrainGroup> All Cybersyn-controlled train groups indexed by Factorio group name
---@field public luatrain_id_to_vehicle_id table<Id, Id> Map of LuaTrain ids to Cybersyn vehicle ids
---@field public rail_id_to_node_id table<UnitNumber, Id> Map of rail unit numbers to node ids of the associated train stop
---@field public stop_id_to_node_id table<UnitNumber, Id> Map from UnitNumbers of `train-stop` entities to the corresponding node id
---@field public stop_layouts table<Id, Cybersyn.TrainStopLayout> Layouts of train stops, indexed by node id
---@field public train_layouts table<Id, Cybersyn.TrainLayout> Layouts of trains, indexed by layout id
---@field public debug_state Cybersyn.Internal.DebugState Debug state, should remain empty unless debug mode is enabled for the save
---@field public surface_index_to_train_topology table<uint,Id> Map from planetary surfaces to associated train topologies
---@field public alerts {[Id]: Cybersyn.Alert} Currently displayed alerts
---@field public alerts_by_entity {[UnitNumber]: {[string]: Id}} Currently displayed alerts, indexed by unit number of the entity they are attached to
---@field public views {[Id]: Cybersyn.View} All views currently active, indexed by id
---@field public entities_being_destroyed UnitNumberSet Set of unit numbers of entities that are currently being destroyed. Cached value only valid during destroy events
storage = {}

---Per-player global state.
---@class (exact) Cybersyn.PlayerState
---@field public player_index int
---@field public open_combinator? Cybersyn.Combinator The combinator currently open in the player's UI, if any.
---@field public combinator_gui_root? int The Relm root id of the open combinator gui.
---@field public connection_render_objects? LuaRenderObject[] The render objects used to visualize connections in the player's UI.
---@field public connection_source? Id ID of the TrainStop from which the player is connecting a shared inventory.
---@field public hide_help? boolean Whether the player has hidden the help pane
---@field public train_gui_pos? [number, number] The position of the train GUI for this player, if any.

---Get the player state for a player, creating it if it doesn't exist.
---@param player_index PlayerIndex
---@return Cybersyn.PlayerState
local function get_or_create_player_state(player_index)
	if not storage.players[player_index] then
		storage.players[player_index] = {
			player_index = player_index,
		}
	end
	return storage.players[player_index]
end
_G.cs2.get_or_create_player_state = get_or_create_player_state

---Get the player state for a player.
---@param player_index PlayerIndex
---@return Cybersyn.PlayerState?
local function get_player_state(player_index)
	return storage.players[player_index]
end
_G.cs2.get_player_state = get_player_state

local function clear_storage()
	storage.players = {}
	storage.vehicles = {}
	storage.combinators = {}
	storage.topologies = {}
	storage.nodes = {}
	storage.inventories = {}
	storage.deliveries = {}
	storage.task_ids = {}
	storage.train_groups = {}
	storage.luatrain_id_to_vehicle_id = {}
	storage.rail_id_to_node_id = {}
	storage.stop_id_to_node_id = {}
	storage.stop_layouts = {}
	storage.train_layouts = {}
	storage.debug_state = {}
	storage.surface_index_to_train_topology = {}
	storage.alerts = {}
	storage.alerts_by_entity = {}
	storage.views = {}
	storage.entities_being_destroyed = {}
end

events.register_dynamic_handler("clear-storage", clear_storage)

events.bind("on_startup", clear_storage, true)
events.bind("on_shutdown", function()
	-- Defer clearing storage until after other shutdown handlers.
	events.dynamic_subtick_trigger("clear-storage", "clear-storage")
end)
