local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

---@param data Cybersyn.Internal.LogisticsThreadData
local function transition_to_poll_inventories(data)
	-- Collect inventories to poll
	local inventories = tlib.t_map_a(storage.inventories, function(inventory)
		return inventory
	end)

	data.signals = {}
	data.inventories = inventories
	data.stride =
		math.ceil(mod_settings.work_factor * cs2.PERF_INVENTORY_POLL_WORKLOAD)
	data.index = 1
	data.state = "poll_inventories"
end

---@param data Cybersyn.Internal.LogisticsThreadData
function _G.cs2.logistics_thread.init(data)
	transition_to_poll_inventories(data)
end
