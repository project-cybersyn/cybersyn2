-- Implementation of an internal event backplane.

if ... ~= "__cybersyn2__.lib.events" then
	return require("__cybersyn2__.lib.events")
end

local logging = require("__cybersyn2__.lib.logging")
local log = logging.log
local TRACE = logging.log_level.trace
local event_tracing_enabled = true -- TODO: fix

local lib = {}

---Create an event.
---@generic T1, T2, T3, T4, T5
---@param name string The name of the event
---@param p1 `T1` Unused, but required for type inference
---@param p2 `T2` Unused, but required for type inference
---@param p3 `T3` Unused, but required for type inference
---@param p4 `T4` Unused, but required for type inference
---@param p5 `T5` Unused, but required for type inference
---@return fun(handler: fun(p1: T1, p2: T2, p3: T3, p4: T4, p5: T5)) on Register a handler for the event
---@return fun(p1: T1, p2: T2, p3: T3, p4: T4, p5: T5) raise Raise the event
local function create_event(name, p1, p2, p3, p4, p5)
	local bindings = {}
	local function on(f)
		bindings[#bindings + 1] = f
	end
	local function raise(...)
		if event_tracing_enabled then
			log(TRACE, "event", name, "Cybersyn event:", name, ...)
		end
		for i = 1, #bindings do
			bindings[i](...)
		end
	end
	return on, raise
end
lib.create_event = create_event

---Enable or disable event tracing, which logs all events by name using
---the TRACE log level. Further filtering can be done using the logging
---library's interface.
---@param enabled boolean
function lib.set_event_tracing_enabled(enabled)
	event_tracing_enabled = enabled
end

return lib
