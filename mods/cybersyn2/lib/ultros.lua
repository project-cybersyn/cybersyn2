if ... ~= "__cybersyn2__.lib.ultros" then
	return require("__cybersyn2__.lib.ultros")
end

local lib = {}

local relm = require("__cybersyn2__.lib.relm")

local noop = function() end
local empty = setmetatable({}, {
	__newindex = noop,
})
local msg_bubble = relm.msg_bubble
local msg_broadcast = relm.msg_broadcast
local Pr = relm.Primitive

local function run_event_handler(handler, me, value, element, event)
	if type(handler) == "function" then
		handler(me, value, element, event)
	elseif type(handler) == "string" then
		relm.msg_bubble(
			me,
			{ key = handler, value = value, element = element, event = event }
		)
	end
end

---Return `then_node` if `cond` is true, otherwise return an empty table. Useful for
---conditional Relm rendering.
---@param cond boolean|nil
---@param then_node Relm.Children
function lib.If(cond, then_node)
	if cond then
		return then_node
	else
		return empty
	end
end

---Call `fn` if `cond` is true, otherwise return an empty table. Useful for
---conditional Relm rendering.
---@param cond boolean|nil
---@param fn fun(...): Relm.Children
function lib.CallIf(cond, fn, ...)
	if cond then
		return fn(...)
	else
		return empty
	end
end

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

function lib.handle_gui_events(...)
	local event_map = {}
	for i = 1, select("#", ...), 2 do
		event_map[select(i, ...) or {}] = select(i + 1, ...)
	end
	return function(me, payload, props, state)
		if payload.key == "factorio_event" then
			---@cast payload Relm.MessagePayload.FactorioEvent
			local handler = event_map[payload.name]
			if handler then handler(me, payload.event, props, state) end
			return true
		end
		return false
	end
end

---Shallowly copies `src` into `dest`, returning `dest`.
---@generic K, V
---@param dest table<K, V>
---@param src table<K, V>?
---@return table<K, V>
function lib.assign(dest, src)
	if not src then return dest end
	for k, v in pairs(src) do
		dest[k] = v
	end
	return dest
end
local assign = lib.assign

---Concatenate two arrays
---@generic T
---@param a1 T[]
---@param a2 T[]
---@return T[]
function lib.concat(a1, a2)
	local A = {}
	for i = 1, #a1 do
		A[i] = a1[i]
	end
	for i = 1, #a2 do
		A[#a1 + i] = a2[i]
	end
	return A
end
local concat = lib.concat

local function va_container(...)
	if select("#", ...) == 1 then
		return nil, select(1, ...)
	else
		return select(1, ...), select(2, ...)
	end
end

local function va_primitive(...) return ... end

---@alias Ultros.VarargNodeFactory fun(props_or_children: Relm.Props | Relm.Children, children?: Relm.Children): Relm.Node

---Creates a factory for customized nodes. If only prop changes are
---needed, you can use this rather than wrapping in virtual nodes.
---@param type string Node type to customize.
---@param default_props Relm.Props
---@param prop_transformer fun(props: table)? A function that will be called with the props table before it is passed to the node.
---@param is_container boolean? If true, the first argument to the constructor can be given as children rather than props.
---@return Ultros.VarargNodeFactory
function lib.customize(type, default_props, prop_transformer, is_container)
	local va_parser = is_container and va_container or va_primitive
	return function(...)
		local props, children = va_parser(...)
		local next_props = assign({}, default_props) --[[@as Relm.Props]]
		assign(next_props, props)
		if prop_transformer then prop_transformer(next_props) end
		next_props.children = children
		return {
			type = type,
			props = next_props,
		}
	end
end

lib.customize_primitive = function(
	default_props,
	prop_transformer,
	is_container
)
	return lib.customize(
		"Primitive",
		default_props,
		prop_transformer,
		is_container
	)
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
local VF = lib.VFlow
lib.HFlow = lib.customize_primitive({
	type = "flow",
	direction = "horizontal",
}, nil, true)
local HF = lib.HFlow
-- TODO: fix buttons to new event handling paradigm
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
lib.Label = function(caption)
	return Pr({
		type = "label",
		caption = caption,
	})
end
lib.BoldLabel = function(caption)
	return Pr({
		type = "label",
		font = "default-bold",
		caption = caption,
	})
end
lib.RtLabel = function(caption)
	return Pr({
		type = "label",
		rich_text_setting = defines.rich_text_setting.enabled,
		caption = caption,
	})
end
--- Rich text label with large font size
lib.RtLgLabel = function(caption)
	return Pr({
		type = "label",
		rich_text_setting = defines.rich_text_setting.enabled,
		font = "default-large",
		caption = caption,
	})
end
lib.RtMultilineLabel = function(caption)
	return Pr({
		type = "label",
		rich_text_setting = defines.rich_text_setting.enabled,
		single_line = false,
		caption = caption,
	})
end

lib.customize_primitive()

-- TODO: implement barriers
local Barrier = relm.define_element({
	name = "Barrier",
	render = function(props) return props.children end,
	message = function() return true end,
})

lib.Titlebar = relm.define_element({
	name = "Titlebar",
	render = function(props)
		return Pr({ type = "flow", direction = "horizontal" }, {
			Pr({
				type = "label",
				caption = props.caption,
				style = "frame_title",
				ignored_by_interaction = true,
			}),
			Pr({
				ref = props.drag_handle_ref,
				type = "empty-widget",
				style = "flib_titlebar_drag_handle",
			}),
			lib.CallIf(props.decoration, props.decoration, props),
			lib.CloseButton(),
		})
	end,
})

lib.WindowFrame = relm.define_element({
	name = "WindowFrame",
	render = function(props)
		local window_ref, drag_handle_ref
		local function set_window(ref)
			window_ref = ref
			if window_ref and drag_handle_ref then
				drag_handle_ref.drag_target = window_ref
			end
		end
		local function set_drag_handle(ref)
			drag_handle_ref = ref
			if window_ref and drag_handle_ref then
				drag_handle_ref.drag_target = window_ref
			end
		end
		local children = concat({
			lib.Titlebar({
				caption = props.caption,
				drag_handle_ref = set_drag_handle,
				decoration = props.decoration,
			}),
		}, props.children)
		return Pr(
			{ ref = set_window, type = "frame", direction = "vertical" },
			children
		)
	end,
})

lib.Dropdown = lib.customize_primitive({
	type = "drop-down",
}, function(props)
	if props.on_change then
		props.listen = true
		props.message_handler = lib.handle_gui_events(
			defines.events.on_gui_selection_state_changed,
			function(me, gui_event, props2)
				local my_elt = gui_event.element
				local value = my_elt.selected_index
				if props2.options then value = props2.options[value].key end
				run_event_handler(props2.on_change, me, value, my_elt, gui_event)
			end
		)
	end
	if props.options then
		local items = {}
		local selected_index = nil
		for i, option in ipairs(props.options) do
			table.insert(items, option.caption)
			if option.key == props.value then selected_index = i end
		end
		props.items = items
		props.selected_index = selected_index
	end
	props.value = nil
end)

lib.Labeled = relm.define_element({
	name = "Labeled",
	render = function(props)
		local label_props = assign({
			type = "label",
			font_color = { 255, 230, 192 },
			font = "default-bold",
			caption = props.caption,
		}, props.label_props)
		local hf_props = assign({
			vertical_align = "center",
			horizontally_stretchable = true,
		}, props)
		return HF(hf_props, {
			Pr(label_props),
			HF({ horizontally_stretchable = true }, {}),
			props.children[1],
		})
	end,
})

lib.SignalPicker = lib.customize_primitive({
	type = "choose-elem-button",
	elem_type = "signal",
}, function(props)
	props.elem_value = props.value
	props.value = nil
	if props.virtual_signal then
		props.elem_value = { type = "virtual", name = props.virtual_signal }
	end

	if props.on_change then
		props.listen = true
		props.message_handler = lib.handle_gui_events(
			defines.events.on_gui_elem_changed,
			function(me, gui_event, props2)
				local my_elt = gui_event.element
				run_event_handler(
					props2.on_change,
					me,
					my_elt.elem_value,
					my_elt,
					gui_event
				)
			end
		)
	end
end)

local function checkbox_customizer(props)
	if props.value == true or props.value == false then
		props.state = props.value
		props.value = nil
	else
		props.state = false
	end

	if props.on_change then
		props.listen = true
		props.message_handler = lib.handle_gui_events(
			defines.events.on_gui_checked_state_changed,
			function(me, gui_event, props2)
				local my_elt = gui_event.element
				run_event_handler(props2.on_change, me, my_elt.state, my_elt, gui_event)
			end
		)
	end

	props.query_handler = function(me, payload)
		if payload.key == "value" and me.elem then return true, me.elem.state end
		return false
	end
end

lib.Checkbox = lib.customize_primitive({
	type = "checkbox",
}, checkbox_customizer)

lib.RadioButton = lib.customize_primitive({
	type = "radiobutton",
}, checkbox_customizer)

lib.WellSection = relm.define_element({
	name = "WellSection",
	render = function(props, state)
		local collapsed = (state or {}).collapsed
		return VF({ bottom_margin = 6, horizontally_squashable = true }, {
			Pr({
				type = "frame",
				style = "subheader_frame",
				horizontally_stretchable = true,
				bottom_margin = 4,
			}, {
				Pr({
					type = "label",
					style = "subheader_caption_label",
					caption = props.caption,
				}),
				lib.If(props.decorate, HF({ horizontally_stretchable = true }, {})),
				lib.CallIf(props.decorate, props.decorate, props, state),
			}),
			VF(
				{
					left_padding = 8,
					right_padding = 8,
					visible = not collapsed,
					horizontally_squashable = true,
				},
				props.children
			),
		})
	end,
	state = function(props) return { collapsed = props.collapsed } end,
})

lib.WellFold = lib.customize("WellSection", {
	collapsed = true,
	decorate = function(_, state)
		return lib.SpriteButton({
			style = "frame_action_button",
			sprite = "utility/add_white",
			on_click = "toggle_fold",
			toggled = not state.collapsed,
		})
	end,
	message_handler = function(me, payload)
		if payload.key == "toggle_fold" then
			relm.set_state(
				me,
				function(prev) return { collapsed = not (prev or {}).collapsed } end
			)
			return true
		end
	end,
})

lib.Switch = lib.customize_primitive({
	type = "switch",
}, function(props)
	if props.value == true or props.value == false then
		props.switch_state = props.value and "right" or "left"
	elseif type(props.value) == "number" then
		props.switch_state = props.value == 0 and "none"
			or (props.value == 1 and "left" or "right")
	end
	props.value = nil

	if props.on_change then
		props.listen = true
		props.message_handler = lib.handle_gui_events(
			defines.events.on_gui_switch_state_changed,
			function(me, gui_event, props2)
				local my_elt = gui_event.element
				local state = my_elt.switch_state
				run_event_handler(
					props2.on_change,
					me,
					state == "none" and 0 or (state == "left" and 1 or 2),
					my_elt,
					gui_event
				)
			end
		)
	end
end)

local function get_text_value(text, is_numeric, is_float)
	if is_numeric then
		local value = tonumber(text)
		if value and not is_float then value = math.floor(value) end
		return value
	else
		return text or ""
	end
end

lib.Input = lib.customize_primitive({
	type = "textfield",
	lose_focus_on_confirm = true,
}, function(props)
	if props.value then
		props.initial_text = tostring(props.value)
		props.value = nil
	end

	if props.on_confirm or props.on_change then
		props.listen = true
		props.message_handler = lib.handle_gui_events(
			defines.events.on_gui_confirmed,
			function(me, gui_event, props2)
				local my_elt = gui_event.element
				run_event_handler(
					props2.on_confirm,
					me,
					get_text_value(my_elt.text, props2.numeric, props2.allow_decimal),
					my_elt,
					gui_event
				)
			end,
			defines.events.on_gui_text_changed,
			function(me, gui_event, props2)
				local my_elt = gui_event.element
				run_event_handler(
					props2.on_change,
					me,
					get_text_value(gui_event.text, props2.numeric, props2.allow_decimal),
					my_elt,
					gui_event
				)
			end
		)
	end
	props.query_handler = function(me, payload)
		if payload.key == "value" and me.elem then return true, me.elem.text end
		return false
	end
end)

lib.Tag = relm.define_element({
	name = "ultros.Tag",
	render = function(props) return props.children end,
	query = function(me, payload, props)
		if payload.propagation_mode == "broadcast" then
			local handled, res = relm.query_broadcast(me, payload, true)
			if handled then return handled, res, props.query_tag end
		end
		return false
	end,
})

function lib.tag(tag, elt) return lib.Tag({ query_tag = tag }, { elt }) end

function lib.gather(tag_or_children, children)
	if type(tag_or_children) == "string" then
		return relm.Gather({ query_tag = tag_or_children }, children)
	else
		return relm.Gather({}, tag_or_children)
	end
end

local function map(A, f)
	local B = {}
	for i = 1, #A do
		local x = f(A[i], i)
		if x ~= nil then B[#B + 1] = x end
	end
	return B
end

lib.RadioButtons = relm.define_element({
	name = "ultros.RadioButtons",
	render = function(props)
		local elems = props.buttons or {}
		return map(elems, function(elem)
			return lib.RadioButton({
				caption = elem.caption,
				value = (elem.key == props.value),
				horizontally_stretchable = true,
				on_change = function(me, value)
					if value then
						relm.msg_bubble(me, { key = "radio_clicked", value = elem.key })
					end
				end,
			})
		end)
	end,
	message = function(me, payload, props)
		if payload.key == "radio_clicked" then
			local value = payload.value
			if value ~= props.value then
				if props.on_change then
					run_event_handler(props.on_change, me, value)
				end
			end
			return true
		end
		return false
	end,
})

return lib
