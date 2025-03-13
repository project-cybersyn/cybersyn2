-- Global auto-incrementing counters stored in game state. Useful for generating unique IDs.

if ... ~= "__cybersyn2__.lib.counters" then
	return require("__cybersyn2__.lib.counters")
end

local lib = {}

---Initialize the counter system. Must be called in the mod's `on_init` handler.
---BEFORE any counters are utilized.
function lib.init()
	if not storage._counters then
		storage._counters = {}
	end
end

---Increment the global counter with the given key and return its next value.
---@param key string The key of the counter to increment.
---@return integer #The next value of the counter
function lib.next(key)
	local counters = storage._counters --[[@as {[string]: integer}]]
	if not counters then
		-- We have to crash here for reasons of determinism.
		error(
			"Attempt to increment a counter before storage was initialized. Make sure you are calling counters.init() in your on_init handler and that you aren't utilizing counters in a phase where storage is inaccessible.")
	end
	local n = (counters[key] or 0) + 1
	counters[key] = n
	return n
end

return lib
