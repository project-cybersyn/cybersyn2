--------------------------------------------------------------------------------
-- Push->dump phase
--------------------------------------------------------------------------------

local cs2 = _G.cs2

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

--------------------------------------------------------------------------------
-- Loop core
--------------------------------------------------------------------------------

function LogisticsThread:enter_alloc_dump() end

function LogisticsThread:alloc_dump() self:set_state("route") end

function LogisticsThread:exit_alloc_dump() end
