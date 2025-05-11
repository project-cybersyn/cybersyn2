--------------------------------------------------------------------------------
-- Push->sink phase
--------------------------------------------------------------------------------

local cs2 = _G.cs2

---@class Cybersyn.LogisticsThread
local LogisticsThread = _G.cs2.LogisticsThread

--------------------------------------------------------------------------------
-- Loop core
--------------------------------------------------------------------------------

function LogisticsThread:enter_alloc_sink() end

function LogisticsThread:alloc_sink() self:set_state("alloc_dump") end

function LogisticsThread:exit_alloc_sink() end
