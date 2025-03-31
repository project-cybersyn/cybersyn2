--------------------------------------------------------------------------------
-- SAFE DYNAMIC EVENT BINDING
-- Allow binding dynamically to events at runtime in a safe way using keyed
-- handlers and storage.
--------------------------------------------------------------------------------

local counters = require("__cybersyn2__.lib.counters")
local log = require("__cybersyn2__.lib.logging")
local relm = require("__cybersyn2__.lib.relm")

---@alias Cybersyn.Internal.DynamicBindings {[int]: [string, any, any]}

---@class Cybersyn.Internal.DynamicHandlerState

local handlers = {}
local bound = {}

local function dispatch(ev, ...)
	local bindings = storage.dynamic_handlers[ev]
	if bindings then
		for _, binding in pairs(bindings) do
			local handler = handlers[binding[1]]
			if handler then
				handler(ev, binding[2], binding[3], ...)
			else
				log.error("binding to unregistered handler", ev, binding[1])
			end
		end
	end
end

local function bind(ev)
	if not bound[ev] then
		bound[ev] = true
		_G.cs2[ev](function(...) return dispatch(ev, ...) end)
	end
end

---@param name string
function _G.cs2.register_dynamic_handler(name, handler)
	if handlers[name] then
		error("duplicate dynamic handler registration" .. name)
	end
	handlers[name] = handler
end

---@param event_name string Name of CS2 event `on_` function eg `on_combinator_created`
---@param handler_name string Name of handler registered with `register_dynamic_handler`.
---@param arg1? any `storage`-safe value passed to the handler along
---with the event args.
---@param arg2? any
---@return int handle Handle for use with `dynamic_unbind`
local function dynamic_bind(event_name, handler_name, arg1, arg2)
	local hs = storage.dynamic_handlers[event_name]
	if not hs then
		storage.dynamic_handlers[event_name] = {}
		hs = storage.dynamic_handlers[event_name]
	end
	local handle = counters.next("dynamic_bind")
	hs[handle] = { handler_name, arg1, arg2 }
	bind(event_name)
	-- XXX: debug
	log.trace("dynamic_bind to", event_name)
	return handle
end
_G.cs2.dynamic_bind = dynamic_bind

---Unbind something previously bound via `dynamic_bind`
---@param handle int
function dynamic_unbind(handle)
	for ev, hs in pairs(storage.dynamic_handlers) do
		-- XXX: debug
		if hs[handle] then log.trace("dynamic_unbind from", ev) end
		hs[handle] = nil
		if table_size(hs) == 0 then storage.dynamic_handlers[ev] = nil end
	end
end
_G.cs2.dynamic_unbind = dynamic_unbind

-- Restore dynamic handlers deterministically on_load
_G.cs2.on_load(function()
	for ev in pairs(storage.dynamic_handlers) do
		bind(ev)
	end
end)

_G.cs2.register_dynamic_handler(
	"relm_message",
	function(ev, handle, key, ...)
		relm.msg(handle, {
			key = key,
			event_name = ev,
			...,
		})
	end
)

local function use_event_binder(handle, evk)
	return dynamic_bind(evk, "relm_message", handle, evk)
end

local function use_event_unbinder(handle)
	if handle then return dynamic_unbind(handle) end
end

---Relm hook to connect to a CS2 event. Your component will receive a message
---with the same name as the `on_event` you specify. `on_event` must be the
---full name of a CS2 event binding function including the `on_` portion.
---The message will carry the event arguments in order in the array
---entries of its payload.
---@param on_event string
function _G.cs2.use_event(on_event)
	relm.use_effect(on_event, use_event_binder, use_event_unbinder)
end
