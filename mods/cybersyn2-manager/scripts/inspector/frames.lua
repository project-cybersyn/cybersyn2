local flib_gui = require("__flib__.gui")
local cs_gui = require("__cybersyn2__.lib.gui")
local tlib = require("__cybersyn2__.lib.table")
local mgr = _G.mgr

cs_gui.register_widget_type({
	name = "frame_close_button",
	create = function()
		---@type flib.GuiElemDef
		local def = {
			type = "sprite-button",
			style = "frame_action_button",
			mouse_button_filter = { "left" },
			sprite = "utility/close",
			hovered_sprite = "utility/close",
		}
		return def
	end,
	handle = function(_, widget, event)
		cs_gui.bubble_event(widget, event, "close")
	end,
})

cs_gui.register_widget_type({
	name = "embed_frame",
	create = function(self, customizations)
		---@type flib.GuiElemDef
		local def = {
			type = "frame",
			direction = "vertical",
			tags = {
				index = customizations.index,
				bubble = {
					close = true,
				},
			},
			children = {
				-- title bar
				{
					type = "flow",
					name = "titlebar",
					children = {
						{
							type = "label",
							name = "caption_label",
							style = "frame_title",
							caption = "unknown",
							elem_mods = { ignored_by_interaction = true },
						},
						{
							type = "empty-widget",
							style = "flib_titlebar_drag_handle",
							elem_mods = { ignored_by_interaction = true },
						},
						cs_gui.create_widget("frame_close_button"),
					},
				},
				-- widget area (empty initially)
			},
		}
		return def
	end,
	update = function(self, element, data)
		local caption = element["titlebar"]["caption_label"]
		caption.caption = data.caption or "unknown"
		local widget = element.children[2]
		local wtype = cs_gui.is_widget(widget)
		local destroy = false
		local create = false
		if widget then
			if data.widget_type then
				if (not wtype) or data.widget_type ~= wtype.name then
					destroy = true
					create = true
				end
			else
				destroy = true
			end
		else
			if data.widget_type then
				create = true
			end
		end
		if destroy then
			widget.destroy()
		end
		if create then
			local new_widget = cs_gui.create_widget(
				data.widget_type,
				data.widget_customizer and data.widget_customizer()
			)
			if new_widget then
				new_widget.index = 2
				flib_gui.add(element, new_widget)
			end
		end
		widget = element.children[2]
		if widget then
			cs_gui.update_widget(widget, data.widget_data)
		end
	end,
})

cs_gui.register_widget_type({
	name = "string_label",
	create = function(self, customizations)
		---@type flib.GuiElemDef
		local def = {
			type = "label",
			caption = "",
			elem_mods = { ignored_by_interaction = true },
		}
		return tlib.assign(def, customizations)
	end,
	update = function(self, element, data)
		element.caption = data
	end,
})

local function embed_frame(index)
	local w = cs_gui.create_widget("embed_frame") --[[@as flib.GuiElemDef]]
	local tags = w.tags
	tags.index = index
	w.tags = tags
	return w
end

local function close_handler(_, widget, event, _, bubble_key)
	local player_index = event.player_index
	if bubble_key == "close" then
		local tags = widget.tags
		if tags and tags.index then
			mgr.inspector.remove_entry(player_index, tags.index --[[@as uint]])
		end
	end
end

cs_gui.register_widget_type({
	name = "inspect_stop",
	create = function(self, customizations)
		return embed_frame(customizations.index)
	end,
	handle = close_handler,
	---@param data Cybersyn.Manager.InspectorEntry
	update = function(self, element, data)
		local result = remote.call("cybersyn2", "query", {
			type = "stops",
			unit_numbers = { data.unit_number },
		})
		cs_gui.update_widget(element, {
			type = "inspect_stop_body",
		})
	end,
})
