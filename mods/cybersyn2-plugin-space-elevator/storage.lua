local events = require("__cybersyn2__.lib.core.event")

---@class CS2.SpaceElevatorPlugin.Train
---@field public id uint64 Pre-transit LuaTrain ID
---@field public delivery_id uint64 Cybersyn Delivery ID
---@field public vehicle_id int64 Cybersyn Train ID
---@field public previous_group string Pre-transit group name.

---@class CS2.SpaceElevatorPlugin.Elevator
---@field public unit_number uint64 The unit number of the stop entity.
---@field public stop LuaEntity The trainstop entity representing this elevator.
---@field public opposite_end CS2.SpaceElevatorPlugin.Elevator Opposite end of this elevator.
---@field public surface_index uint32 The surface index this elevator is on.

---@alias CS2.SpaceElevatorPlugin.ElevatorSet {[uint64]: CS2.SpaceElevatorPlugin.Elevator}

---@class CS2.SpaceElevatorPlugin.Storage
---@field public trains table<int64, CS2.SpaceElevatorPlugin.Train> Trains being tracked by the space elevator plugin. Indexed by pre-transit LuaTrain ID.
---@field public elevators CS2.SpaceElevatorPlugin.ElevatorSet Elevators by unit number.
---@field public elevators_by_surface table<uint32, CS2.SpaceElevatorPlugin.ElevatorSet>
storage = {}

local function reset_storage()
	storage.trains = {}
	storage.elevators = {}
	storage.elevators_by_surface = {}
end

events.bind("on_startup", function() reset_storage() end, true)

commands.add_command(
	"cs2-space-elevator-reset-storage",
	"Reset the cybersyn2 space elevator plugin storage (for debugging).",
	function() reset_storage() end
)
