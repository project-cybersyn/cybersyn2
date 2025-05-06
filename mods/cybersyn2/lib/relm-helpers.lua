--------------------------------------------------------------------------------
-- Connect Relm to dynamic binding and threads through effect handlers.
--------------------------------------------------------------------------------

if ... ~= "__cybersyn2__.lib.relm-helpers" then
	return require("__cybersyn2__.lib.relm-helpers")
end

local relm = require("__cybersyn2__.lib.relm")
local db = require("__cybersyn2__.lib.dynamic-binding")
local scheduler = require("__cybersyn2__.lib.scheduler")

local lib = {}

--------------------------------------------------------------------------------
-- Events -> Relm
--------------------------------------------------------------------------------

-- Generic handler to convert dynamic events to relm messages
db.register_dynamic_handler(
	"relm_message",
	function(ev, arg, ...)
		relm.msg(arg[1], {
			key = arg[2],
			event_name = ev,
			...,
		})
	end
)

local function use_event_binder(handle, event_name)
	return db.dynamic_bind(event_name, "relm_message", { handle, event_name })
end

local function use_event_unbinder(id)
	if id then return db.dynamic_unbind(id) end
end

---Bind a Relm component to an event using `dynamic_events`. Whenever the
---event is dispatched, your
---component will receive a message with the event name as key, and
---the event args in the array portion of the payload.
---@param on_event string
function lib.use_event(on_event)
	relm.use_effect(on_event, use_event_binder, use_event_unbinder)
end

--------------------------------------------------------------------------------
-- Scheduler -> Relm
--------------------------------------------------------------------------------

scheduler.register_handler("relm_timer", function(task)
	local data = task.data
	if data then
		local component = data[1]
		if relm.is_valid(component) then
			relm.msg(component, { key = data[2] })
			return
		end
	end
	return scheduler.ABORT
end)

local function use_timer_binder(handle, period_msg)
	return scheduler.every(period_msg[1], "relm_timer", { handle, period_msg[2] })
end

local function use_timer_unbinder(id) scheduler.stop(id) end

---Send the given message to the component every `period` ticks.
---@param period uint The period in ticks to send the message.
---@param msg string The message to send to the component. The message will be sent with the key `msg`.
function lib.use_timer(period, msg)
	relm.use_effect({ period, msg }, use_timer_binder, use_timer_unbinder)
end

return lib
