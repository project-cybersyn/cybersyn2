if ... ~= "__cybersyn2__.lib.ultros" then
	return require("__cybersyn2__.lib.ultros")
end

local lib = {}

local log = require("__cybersyn2__.lib.logging")
local relm = require("__cybersyn2__.lib.relm")

local noop = function() end
local msg_bubble = relm.msg_bubble
local msg_broadcast = relm.msg_broadcast

---Generate a transform function for use with a `message_handler` prop. This
---function will transform messages targeting the node and forward them to
---the element's base handler. If the base handler doesn't handle the message
---it will be propagated in the same mode as the original message.
---@param mapper fun(payload: Relm.MessagePayload, props?: Relm.Props, state?: Relm.State): Relm.MessagePayload? Function taking an incoming message payload and transforming it to a new one, or returning `nil` if the message should be absorbed.
---@return Relm.Element.MessageHandlerWrapper
function lib.transform(mapper)
	return function(me, payload, props, state, base_handler)
		-- Transform and delegate to base
		local mapped = mapper(payload, props, state)
		if not mapped or (base_handler or noop)(me, mapped, props, state) then
			return true
		end
		-- If declined, rebroadcast mapped message
		if payload.propagation_mode == "bubble" then
			msg_bubble(me, mapped, true)
		elseif payload.propagation_mode == "broadcast" then
			msg_broadcast(me, mapped, true)
		end
		-- Treat as handled
		return true
	end
end

---Transform Factorio events given by their `defines.events` name to new
---message keys. Args are given as `event1, key1, event2, key2, ...` pairs.
---The new key will be used in the `key` field of the transformed message payload.
---@return Relm.Element.MessageHandlerWrapper
function lib.transform_events(...)
	local event_map = {}
	for i = 1, select("#", ...), 2 do
		event_map[select(i, ...) or {}] = select(i + 1, ...)
	end
	return lib.transform(function(msg)
		if msg.key == "factorio_event" then
			---@cast msg Relm.MessagePayload.FactorioEvent
			local new_key = event_map[msg.name]
			if new_key then
				return { key = new_key, event = msg.event }
			else
				return msg
			end
		end
	end)
end

return lib
