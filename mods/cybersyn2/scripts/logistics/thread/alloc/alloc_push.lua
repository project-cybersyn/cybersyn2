--------------------------------------------------------------------------------
-- Push->pull phase
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

---@param item SignalKey
function LogisticsThread:alloc_push_item(item) end

--------------------------------------------------------------------------------
-- Loop core
--------------------------------------------------------------------------------

function LogisticsThread:enter_alloc_push() end

function LogisticsThread:alloc_push() self:set_state("alloc_pull") end

function LogisticsThread:exit_alloc_push() end
