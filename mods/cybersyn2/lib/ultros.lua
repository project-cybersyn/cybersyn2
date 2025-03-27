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
function lib.map_events(...)
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

---Shallowly copies `src` into `dest`, returning `dest`.
---@generic K, V
---@param dest table<K, V>
---@param src table<K, V>?
---@return table<K, V>
local function assign(dest, src)
	if not src then
		return dest
	end
	for k, v in pairs(src) do
		dest[k] = v
	end
	return dest
end

local function va_container(...)
	if select("#", ...) == 1 then
		return nil, select(1, ...)
	else
		return select(1, ...), select(2, ...)
	end
end

local function va_primitive(...)
	return ...
end

---@alias Ultros.VarargNodeFactory fun(props_or_children: Relm.Props | Relm.Children, children?: Relm.Children): Relm.Node

---Creates a factory for customized primitive nodes. If only prop changes are
---needed, you can use this rather than wrapping primitives in virtual nodes.
---@param default_props Relm.Props
---@param prop_transformer fun(props: table)? A function that will be called with the props table before it is passed to the node.
---@param is_container boolean? If true, the first argument to the constructor can be given as children rather than props.
---@return Ultros.VarargNodeFactory
function lib.customize_primitive(default_props, prop_transformer, is_container)
	local va_parser = is_container and va_container or va_primitive
	return function(...)
		local props, children = va_parser(...)
		local next_props = assign({}, default_props) --[[@as Relm.Props]]
		assign(next_props, props)
		if prop_transformer then
			prop_transformer(next_props)
		end
		next_props.children = children
		return {
			type = "Primitive",
			props = next_props,
		}
	end
end

local function on_click_transformer(props)
	if props.on_click then
		props.listen = true
		props.message_handler =
			lib.map_events(defines.events.on_gui_click, props.on_click)
	end
end

lib.VFlow = lib.customize_primitive({
	type = "flow",
	direction = "vertical",
}, nil, true)
lib.HFlow = lib.customize_primitive({
	type = "flow",
	direction = "horizontal",
}, nil, true)
lib.Button = lib.customize_primitive({
	type = "button",
	style = "button",
}, on_click_transformer)
lib.SpriteButton = lib.customize_primitive({
	type = "sprite-button",
}, on_click_transformer)
lib.CloseButton = lib.customize_primitive({
	type = "sprite-button",
	style = "frame_action_button",
	sprite = "utility/close",
	hovered_sprite = "utility/close",
	mouse_button_filter = { "left" },
	on_click = "close",
}, on_click_transformer)

return lib
