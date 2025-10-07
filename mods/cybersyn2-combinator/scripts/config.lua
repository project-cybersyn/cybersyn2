local constants = require "scripts.constants"
local startup = settings.startup

local slot_count_wagon = tonumber(startup[constants.SETTINGS.SLOT_COUNT_WAGON].value)

if not slot_count_wagon then
  error("wagon slot count is not a valid number")
end

--- @class CybersynSignal
--- @field slot uint
--- @field default integer
--- @field min integer
--- @field max integer

local config = {
  --- @type table<string, CybersynSignal>
  cs_signals = {
    [constants.SETTINGS.CS_PRIORITY_NAME] = {
      slot = 1,
      default = constants.SETTINGS.CS_DEFAULT_PRIORITY,
      min = constants.INT32_MIN,
      max = constants.INT32_MAX
    }
  }
}

return config
