--------------------------------------------------------------------------------
-- SAFE DYNAMIC EVENT BINDING
-- Allow binding dynamically to events at runtime in a safe way using keyed
-- handlers and storage.
--------------------------------------------------------------------------------

if ... ~= "__cybersyn2__.lib.dynamic-binding" then
	return require("__cybersyn2__.lib.dynamic-binding")
end

local lib = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

---@alias DynamicBinding.Event {[int]: [string, any, any]}

---@alias DynamicBinding.Events {[string]: DynamicBinding.Event}

local handlers = {}
local bound_events = {}
local bind_handler = function(_) end

local function bind(event_name)
	if not bound_events[event_name] then
		bound_events[event_name] = true
		bind_handler(event_name)
	end
end

---Initialize the binding system. MUST be called in the mod's `on_init` handler.
function lib.init()
	if not storage._dynbind then
		storage._dynbind = { id = 0, events = {}, id_key = {} }
	end
end

---Restore dynamic bindings across save barriers. MUST be called in the mod's
---`on_load` handler to avoid desyncs.
function lib.on_load()
	for ev in
		pairs(storage._dynbind.events --[[@as DynamicBinding.Events]])
	do
		bind(ev)
	end
end

--------------------------------------------------------------------------------
-- Handlers
--------------------------------------------------------------------------------

---Dispatch an event to all dynamically bound handlers.
---@param event_name string
function lib.dispatch(event_name, ...)
	local event = storage._dynbind.events[event_name] --[[@as DynamicBinding.Events]]
	if not event then return end
	for _, binding in pairs(event) do
		local handler = handlers[binding[1]]
		if handler then handler(event_name, binding[2], binding[3], ...) end
	end
end

---Register a named handler that can be bound to dynamic events
---@param name string
---@param handler fun(event_name: string, arg1: any, arg2: any, ...)
function lib.register_dynamic_handler(name, handler)
	if handlers[name] then
		error("duplicate dynamic handler registration" .. name)
	end
	handlers[name] = handler
end

---`on_event_bound` handler is invoked whenever a dynamic binding to a new
---event is seen or `on_load` when bindings are being restored. You should
---use the handler to make sure your mod is calling `dispatch` whenever it
---sees the corresponding event. The handler will only be called once per
---named event per Lua session.
---@param handler fun(event_name: string)
function lib.on_event_bound(handler) bind_handler = handler end

--------------------------------------------------------------------------------
-- Binding
--------------------------------------------------------------------------------

---Dynamically bind to an event. Whenever the event is dispatched,
---the handler given by `handler_name` (which must be previously registered
---using `register_dynamic_handler`) will be called with the given arg
---followed by the event args.
---
---Note that args are persisted to `storage`.
---@param event_name string Name of the event to bind to.
---@param handler_name string Handler to call when the event is raised. Must be registered by `register_dynamic_handler`.
---@param arg any Stored argument provided to the handler.
---@return int id A handle that can be used with `dynamic_unbind` to remove the binding.
function lib.dynamic_bind(event_name, handler_name, arg)
	local event = storage._dynbind.events[event_name] --[[@as DynamicBinding.Event?]]
	if not event then
		storage._dynbind.events[event_name] = {}
		event = storage._dynbind.events[event_name]
	end
	local id = storage._dynbind.id + 1
	storage._dynbind.id = id
	event[id] = { handler_name, arg }
	bind(event_name)
	return id
end

---Unbind a handler previously bound with `dynamic_bind`.
---@param id int The value returned by `dynamic_bind`
---@return boolean #`true` if an event was unbound.
function lib.dynamic_unbind(id)
	for event_name, event in pairs(storage._dynbind.events) do
		if event[id] then
			event[id] = nil
			if table_size(event) == 0 then
				storage._dynbind.events[event_name] = nil
			end
			return true
		end
	end
	return false
end

return lib
