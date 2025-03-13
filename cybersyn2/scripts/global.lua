---@class (exact) Cybersyn.Storage
---@field public players table<PlayerIndex, Cybersyn.PlayerState> Per-player state.
---@field public task_ids table<string, Scheduler.TaskId> Ids of core tasks.
---@field public train_groups table<string, Cybersyn.TrainGroup> All Cybersyn-controlled train groups, indexed by Factorio group name.
---@field public vehicles table<Id, Cybersyn.Vehicle> All Cybersyn vehicles, indexed by id.
---@field public luatrain_id_to_vehicle_id table<Id, Id> Map of LuaTrain ids to Cybersyn vehicle ids.

---@class (exact) Cybersyn.PlayerState Per-player global state.
---@field public player_index int
---@field public open_combinator? Cybersyn.Combinator.Ephemeral The combinator OR ghost currently open in the player's UI, if any.
---@field public open_combinator_unit_number? UnitNumber The unit number of the combinator currently open in the player's UI, if any. This is stored separately to allow for cases where the combinator is removed while the UI is open, eg ghost revival.

-- Initialize gamestate storage at mod init.
on_init(function()
	storage.players = {}
	storage.task_ids = {}
	storage.train_groups = {}
	storage.vehicles = {}
	storage.luatrain_id_to_vehicle_id = {}
end, true)
