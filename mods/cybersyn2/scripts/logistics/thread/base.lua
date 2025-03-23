--------------------------------------------------------------------------------
-- Logistics thread
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local scheduler = require("__cybersyn2__.lib.scheduler")
local cs2 = _G.cs2
local threads_api = _G.cs2.threads_api

_G.cs2.logistics_thread = {}

---@class (exact) Cybersyn.Internal.LogisticsThreadData
---@field state "init"|"poll_inventories"|"poll_nodes"|"create_deliveries" State of the task.
---@field stride int The number of trains to process per iteration
---@field index int The current index in the enumeration.
---@field inventories Cybersyn.Inventory[]? The inventories to poll.
---@field signals table<UnitNumber, Signal[]> Cache of signals read during poll phases, indexed by combinator ID.
---@field nodes Cybersyn.Node[]? The nodes to poll.
---@field item_network_names string[]? All `item_network_names`
---@field requesters table<string, Id[]>? Map of item network names to requester node ids
---@field providers table<string, Id[]>? Map of item network names to provider node ids

---@class Cybersyn.Internal.LogisticsThread: Scheduler.RecurringTask
---@field public data Cybersyn.Internal.LogisticsThreadData

threads_api.schedule_thread(
	"logistics_thread",
	threads_api.create_standard_main_loop(_G.cs2.logistics_thread),
	0
)

--------------------------------------------------------------------------------
-- Helper fns
--------------------------------------------------------------------------------

-- TODO: Rewrite this, it should be ok to just cache the raw signals in
-- global combinator cache, plus will help with debugging.

---Pull signals from thread cache or combinator.
---@param data Cybersyn.Internal.LogisticsThreadData
---@param combinator_entity LuaEntity The combinator entity to read from.
---@return Signal[]?
function _G.cs2.logistics_thread.get_combinator_signals(data, combinator_entity)
	local id = combinator_entity.unit_number --[[@as UnitNumber]]
	local signals = data.signals[id] --[[@as Signal[]?]]
	if not signals then
		signals = combinator_entity.get_signals(
			defines.wire_connector_id.circuit_red,
			defines.wire_connector_id.circuit_green
		)
		data.signals[id] = signals
	end
	return signals
end

-- Logistics thread:
-- - `init`
-- 		- Collect all `Inventory`s, clear data
-- 		- Transition to `poll_inventories`
-- - `poll_inventories`
-- 		- Poll all combinators governing inventories
-- 		- Store values in cache via `inventory_api.set_inventory_from_signals`
-- 		- Transition to `poll_nodes`
-- - `poll_nodes`
-- 		- Update all train stops for network and settings
-- 		- Create cache of item names, providers of each item, requesters of each item
