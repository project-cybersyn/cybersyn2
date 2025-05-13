--------------------------------------------------------------------------------
-- Cull phase
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

function LogisticsThread:cull_item(_, item)
	local providers_i = self.providers[item]
	if providers_i and next(providers_i) then
		local pullers_i = self.pullers[item]
		if not pullers_i or not next(pullers_i) then
			-- Cull provided items that aren't pulled.
			self.providers[item] = nil
			local sinks_i = self.sinks[item]
			local pushers_i = self.pushers[item]
			if
				(not sinks_i or not next(sinks_i))
				and (not pushers_i or not next(pushers_i))
			then
				-- Cull totally from seen cargo if not pushed or sunk.
				self.seen_cargo[item] = nil
				self.n_culled = self.n_culled + 1
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Loop core
--------------------------------------------------------------------------------

function LogisticsThread:enter_cull()
	self.n_culled = 0
	self:begin_async_pairs(
		-- Fix: clone the table here because the lua guarantee of being
		-- able to remove while iterating does not apply across Factorio
		-- save boundaries.
		tlib.assign({}, self.seen_cargo),
		math.ceil(mod_settings.work_factor * cs2.PERF_CULL_WORKLOAD)
	)
end

function LogisticsThread:cull()
	self:step_async_pairs(
		self.cull_item,
		function(thr) thr:set_state("alloc") end
	)
end
