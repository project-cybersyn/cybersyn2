---@class (exact) Cybersyn.Storage
---@field public update_number uint The total number of Cybersyn updates since the beginning of the save.
---@field public players {[PlayerIndex]: Cybersyn.PlayerState} Per-player state.

on_init(function()
	storage.update_number = 0
	storage.players = {}
end)
