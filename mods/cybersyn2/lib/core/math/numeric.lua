local floor = math.floor

local lib = {}

---Round to nearest factor of `bracket`.
---@param v number The value to round.
---@param bracket? number The rounding bracket. Defaults to 1.
local function round(v, bracket)
	bracket = bracket or 1
	local sign = (v >= 0 and 1) or -1
	return floor(v / bracket + 0.5) * bracket
end
lib.round = round

---Format a number of ticks in the form "HH:MM:SS" where a second is
---60 ticks.
---@param ticks uint The number of ticks.
function lib.format_ticks(ticks)
	local seconds = floor(ticks / 60)
	local minutes = floor(seconds / 60)
	local hours = floor(minutes / 60)
	seconds = seconds % 60
	minutes = minutes % 60
	hours = hours % 24
	return string.format("%d:%02d:%02d vs", hours, minutes, seconds)
end

---Format a tick as T+ or T- relative to a given T.
---@param ticks uint The number of ticks.
---@param reference uint The reference tick.
function lib.format_tick_relative(ticks, reference)
	if ticks >= reference then
		return "T+" .. lib.format_ticks(ticks - reference)
	elseif ticks < reference then
		return "T-" .. lib.format_ticks(reference - ticks)
	end
end

return lib
