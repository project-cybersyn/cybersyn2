if ... ~= "__cybersyn2__.lib.gui" then
	return require("__cybersyn2__.lib.gui")
end

local flib_gui = require("__flib__.gui")

-- Below is from flib.
-- TODO: consider removing this and requiring devs to ref flib by hand.

--- A GUI element definition. This extends `LuaGuiElement.add_param` with several new attributes.
--- Children may be defined in the array portion as an alternative to the `children` subtable.
--- @class flib.GuiElemDef: LuaGuiElement.add_param.button|LuaGuiElement.add_param.camera|LuaGuiElement.add_param.checkbox|LuaGuiElement.add_param.choose_elem_button|LuaGuiElement.add_param.drop_down|LuaGuiElement.add_param.flow|LuaGuiElement.add_param.frame|LuaGuiElement.add_param.line|LuaGuiElement.add_param.list_box|LuaGuiElement.add_param.minimap|LuaGuiElement.add_param.progressbar|LuaGuiElement.add_param.radiobutton|LuaGuiElement.add_param.scroll_pane|LuaGuiElement.add_param.slider|LuaGuiElement.add_param.sprite|LuaGuiElement.add_param.sprite_button|LuaGuiElement.add_param.switch|LuaGuiElement.add_param.tab|LuaGuiElement.add_param.table|LuaGuiElement.add_param.text_box|LuaGuiElement.add_param.textfield
--- @field style_mods LuaStyle? Modifications to make to the element's style.
--- @field elem_mods LuaGuiElement? Modifications to make to the element itself.
--- @field drag_target string? Set the element's drag target to the element whose name matches this string. The drag target must be present in the `elems` table.
--- @field handler (flib.GuiElemHandler|table<defines.events, flib.GuiElemHandler>)? Handler(s) to assign to this element. If assigned to a function, that function will be called for any GUI event on this element.
--- @field children flib.GuiElemDef[]? Children to add to this element.
--- @field tab flib.GuiElemDef? To add a tab, specify `tab` and `content` and leave all other fields unset.
--- @field content flib.GuiElemDef? To add a tab, specify `tab` and `content` and leave all other fields unset.

--- A handler function to invoke when receiving GUI events for this element.
--- @alias flib.GuiElemHandler fun(e: flib.GuiEventData)

--- Aggregate type of all possible GUI events.
--- @alias flib.GuiEventData EventData.on_gui_checked_state_changed|EventData.on_gui_click|EventData.on_gui_closed|EventData.on_gui_confirmed|EventData.on_gui_elem_changed|EventData.on_gui_location_changed|EventData.on_gui_opened|EventData.on_gui_selected_tab_changed|EventData.on_gui_selection_state_changed|EventData.on_gui_switch_state_changed|EventData.on_gui_text_changed|EventData.on_gui_value_changed

local lib = {}

---@class WidgetType
---@field public name string The name of the widget type.
---@field public create fun(self: WidgetType, customizations: any): flib.GuiElemDef Create a flib definition of a widget of this type. Must return a new table that flib can mutate; use deep_copy if need be.
---@field public update? fun(self: WidgetType, element: LuaGuiElement, data: any) Update the widget with the given data. The element is guaranteed to be valid and of the correct type. If this function is not given, widget is static.
---@field public handle? fun(self: WidgetType, widget: LuaGuiElement, event: flib.GuiEventData, source_widget: LuaGuiElement?, event_key: string?) Handle an event targeting the widget or bubbled from below. If provided, automatically wires an flib handler to call this handler.

---@type table<string, WidgetType>
local widget_types = {}

---@param e flib.GuiEventData
local function flib_widget_handler(e)
	local elem = e.element
	if not elem then
		return
	end
	local tags = elem.tags
	if not tags then
		return
	end
	local wtype = tags._widget --[[@as string]]
	if not wtype then
		return
	end
	local wdef = widget_types[wtype]
	if not wdef or not wdef.handle then
		return
	end
	wdef.handle(wdef, elem, e)
end
flib_gui.add_handlers({
	["__widget__"] = flib_widget_handler,
})

---@param type WidgetType The widget type to register.
function lib.register_widget_type(type)
	if widget_types[type.name] then
		error("Widget type " .. type.name .. " already registered.")
	end
	widget_types[type.name] = type
end

---Get the widget type definition for a name.
---@param name string The name of the widget type.
---@return WidgetType? #The widget type, or nil if it is not registered.
function lib.get_widget_type(name)
	return widget_types[name]
end

---Determine if a UI element is a dynamic widget and return its type.
---@param elem LuaGuiElement?
---@return WidgetType? #The type of the widget, or nil if it is not a widget.
function lib.is_widget(elem)
	if elem and elem.valid and elem.tags then
		return widget_types[
			elem.tags._widget --[[@as string]]
		]
	end
end

---Update an element that is a widget.
---@param elem LuaGuiElement A *valid* element, e.g. one for which is_widget returns.
---@param data any Data to pass to the widget's paint function
function lib.update_widget(elem, data)
	local wtype = elem.tags and elem.tags._widget --[[@as string]]
	if wtype then
		local wdef = widget_types[wtype]
		if wdef and wdef.update then
			wdef.update(wdef, elem, data)
		end
	end
end

---Retrieve a context key for this widget. Iterates to the root of the
---UI tree looking for a widget with this state key, and returns that.
---@param widget LuaGuiElement The widget to start from.
---@param key string The key to look for.
function lib.get_context(widget, key)
	while widget do
		local tags = widget.tags
		if tags and tags._widget then
			local value = tags[key]
			if value then
				return value
			end
		end
		widget = widget.parent
	end
end

---Set a context value on a widget.
---@param widget LuaGuiElement The widget to set the value on.
---@param key string The key to set.
---@param value Tags|boolean|string|number|int
function lib.set_context(widget, key, value)
	local tags = widget.tags
	if not tags._widget then
		return
	end
	tags[key] = value
	widget.tags = tags
end

---@param widget_type WidgetType|string The type of widget to create.
---@return flib.GuiElemDef? #The flib def of the new widget or `nil`.
function lib.create_widget(widget_type, customizations)
	if type(widget_type) == "string" then
		widget_type = widget_types[widget_type]
	end
	if not widget_type then
		return nil
	end
	local def = widget_type.create(widget_type, customizations)
	local tags = def.tags or {}
	tags._widget = widget_type.name
	def.tags = tags
	if widget_type.handle then
		def.handler = flib_widget_handler
	end
	return def
end

---Bubble an event to a parent widget that matches the given key.
---@param widget LuaGuiElement The original source widget of the event.
---@param event flib.GuiEventData The event to delegate.
---@param key string The key to look for, or a function to locate the delegatee.
function lib.bubble_event(widget, event, key)
	local source_widget = widget
	while widget do
		local tags = widget.tags
		if tags and tags._widget and tags.bubble and tags.bubble[key] then
			local wtype = widget_types[
				tags._widget --[[@as string]]
			]
			if wtype and wtype.handle then
				wtype.handle(wtype, widget, event, source_widget, key)
				return
			end
			return
		end

		widget = widget.parent
	end
end

return lib
