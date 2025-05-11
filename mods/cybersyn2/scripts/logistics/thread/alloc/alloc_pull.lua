--------------------------------------------------------------------------------
-- Provider->pull phase
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

local empty = tlib.empty

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

function LogisticsThread:alloc_pull_item(item) end

--------------------------------------------------------------------------------
-- Loop core
--------------------------------------------------------------------------------

function LogisticsThread:enter_alloc_pull()
	-- Generate list of pulled items
	local providers = self.providers or empty
	local pushers = self.pushers or empty
	self.pulled_items = tlib.t_map_a(self.pullers, function(_, item)
		if providers[item] or pushers[item] then return item end
	end)

	self:begin_async_loop(
		self.pulled_items,
		math.ceil(cs2.PERF_NODE_POLL_WORKLOAD * mod_settings.work_factor)
	)
end

function LogisticsThread:alloc_pull()
	self:step_async_loop(
		self.alloc_pull_item,
		function(thr) thr:set_state("alloc_sink") end
	)
end

function LogisticsThread:exit_alloc_pull() self.pulled_items = nil end
