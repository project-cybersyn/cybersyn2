--------------------------------------------------------------------------------
-- Reusable Relm elements for combinator gui
--------------------------------------------------------------------------------

local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local cs2 = _G.cs2
local Pr = relm.Primitive
local HF = ultros.HFlow
local gui = _G.cs2.gui

---An `ultros.Checkbox` that reads from and writes to a combinator
---setting automatically.
---@param caption LocalisedString
---@param tooltip LocalisedString?
---@param combinator Cybersyn.Combinator
---@param setting string
---@param inverse boolean? If true, the checkbox will be inverted (checked when the setting is false).
---@param disabled boolean? If true, the checkbox will be disabled and not interactable.
---@param value_when_disabled boolean? If `disabled` is true, this will be the value shown in the checkbox.
---@param hidden boolean? If true, the entire control will be hidden.
function _G.cs2.gui.Checkbox(
	caption,
	tooltip,
	combinator,
	setting,
	inverse,
	disabled,
	value_when_disabled,
	hidden
)
	local value = combinator["get_" .. setting](combinator)
	local setter = combinator["set_" .. setting]
	if inverse then value = not value end
	if disabled and value_when_disabled ~= nil then
		value = value_when_disabled
	end
	local enabled = not disabled
	return ultros.Checkbox({
		visible = not hidden,
		caption = caption,
		tooltip = tooltip,
		value = value,
		enabled = enabled,
		on_change = function(_, state)
			local new_state = state
			if inverse then new_state = not state end
			setter(combinator, new_state)
		end,
	})
end

---An `ultros.SignalPicker` that reads/writes a `SignalID` to/from a
---combinator setting.
---@param setting string The name of the setting to read/write.
function _G.cs2.gui.AnySignalPicker(combinator, setting, tooltip)
	local setter = combinator["set_" .. setting]
	return ultros.SignalPicker({
		tooltip = tooltip,
		value = combinator["get_" .. setting](combinator),
		on_change = function(_, signal)
			if signal and signal.type == nil then signal.type = "item" end
			setter(combinator, signal)
		end,
	})
end

---An `ultros.SignalPicker` that reads/writes a `SignalID` to/from a
---combinator setting. Only allows virtual signals.
---@param setting string The name of the setting to read/write.
function _G.cs2.gui.VirtualSignalPicker(combinator, setting, tooltip)
	local setter = combinator["set_" .. setting]
	return ultros.SignalPicker({
		tooltip = tooltip,
		value = combinator["get_" .. setting](combinator),
		on_change = function(_, signal, elem)
			if not signal then return setter(combinator, nil) end
			if signal.type == "virtual" then
				setter(combinator, signal)
			else
				game.print("Invalid signal type. Please select a virtual signal.", {
					color = { 255, 128, 0 },
					skip = defines.print_skip.never,
					sound = defines.print_sound.always,
				})
				elem.elem_value = nil
				return
			end
		end,
	})
end

---An `ultros.SignalPicker` that reads/writes a `SignalID` to/from a
---combinator setting. Only allows valid network signals.
---@param setting string The name of the setting to read/write.
function _G.cs2.gui.NetworkSignalPicker(combinator, setting, tooltip)
	local setter = combinator["set_" .. setting]
	return ultros.SignalPicker({
		tooltip = tooltip,
		virtual_signal = combinator["get_" .. setting](combinator),
		on_change = function(_, signal, elem)
			if not signal then return setter(combinator, nil) end
			if
				signal.type == "virtual"
				and not cs2.INVALID_NETWORK_SIGNAL_SET[signal.name]
			then
				local stored = signal.name
				setter(combinator, stored)
			else
				game.print(
					{ "cybersyn2-gui.virtual-signals-only" },
					cs2.ERROR_PRINT_OPTS
				)
				elem.elem_value = nil
			end
		end,
	})
end

---@param setting string
function _G.cs2.gui.Dropdown(user_props, combinator, setting, options)
	local value = combinator["get_" .. setting](combinator)
	local setter = combinator["set_" .. setting]
	local props = ultros.assign({
		value = value,
		options = options,
		on_change = function(_, selected) setter(combinator, selected) end,
	}, user_props)
	return ultros.Dropdown(props)
end

_G.cs2.gui.InnerHeading = ultros.customize_primitive({
	type = "label",
	font_color = { 255, 230, 192 },
	top_margin = 6,
	font = "default-bold",
})

---@param tooltip LocalisedString?
---@param setting string
function _G.cs2.gui.Switch(tooltip, is_tristate, L, R, combinator, setting)
	local setter = combinator["set_" .. setting]
	return ultros.Switch({
		left_label_caption = L,
		right_label_caption = R,
		tooltip = tooltip,
		allow_none_state = is_tristate,
		value = combinator["get_" .. setting](combinator),
		on_change = function(_, state) setter(combinator, state) end,
	})
end

_G.cs2.gui.Input = relm.define_element({
	name = "CombinatorGui.Input",
	render = function(props, state)
		local combinator = props.combinator
		local dirty = not not (state and state.dirty)
		local value = combinator["get_" .. props.setting](combinator)
		if not value and props.displayed_default_value then
			value = props.displayed_default_value
		end
		local tf_props = ultros.assign({
			value = value,
			on_change = "on_change",
			on_confirm = "on_confirm",
		}, props)

		return HF({
			Pr({ type = "label", caption = "*", visible = dirty }),
			ultros.Input(tf_props),
		})
	end,
	message = function(me, message, props)
		if message.key == "on_change" then
			relm.set_state(me, { dirty = true })
			return true
		elseif message.key == "on_confirm" then
			-- Handle on_confirm to save the value and clear dirty state
			props.combinator["set_" .. props.setting](props.combinator, message.value)
			relm.set_state(me, { dirty = false })
			return true
		else
			return false
		end
	end,
})

local STATUS_COLOR_SPRITES = {
	red = "utility/status_not_working",
	green = "utility/status_working",
	yellow = "utility/status_yellow",
}

_G.cs2.gui.Status = relm.define_element({
	name = "CombinatorGui.Status",
	render = function(props)
		return HF({ vertical_align = "center" }, {
			Pr({
				type = "sprite",
				sprite = STATUS_COLOR_SPRITES[props.color or "green"],
				style = "status_image",
				stretch_image_to_widget_size = true,
			}),
			Pr({
				type = "label",
				caption = props.caption,
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- ORDER INPUT WIRE SETTINGS
-- This is lifted here because it's used by multiple combinator modes.
--------------------------------------------------------------------------------

local andor_dropdown_items = {
	{ key = "and", caption = { "cybersyn2-combinator-mode-inventory.and" } },
	{ key = "or", caption = { "cybersyn2-combinator-mode-inventory.or" } },
}

_G.cs2.gui.OrderWireSettings = relm.define_element({
	name = "OrderWireSettings",
	render = function(props)
		local combinator = props.combinator
		local wire_color = props.wire_color
		local arity = props.arity or "primary"
		local is_request_only = props.is_request_only
		local is_provide_only = props.is_provide_only

		return ultros.WellSection({
			caption = {
				"",
				"[color=",
				wire_color,
				"]Order settings[/color]",
			},
		}, {
			ultros.Labeled({
				caption = "Item network",
				top_margin = 6,
			}, {
				gui.NetworkSignalPicker(
					props.combinator,
					"order_" .. arity .. "_network",
					"The item network for this order. If set to the 'Each' virtual signal, all input virtual signals will be treated as item networks."
				),
			}),
			ultros.Labeled({
				caption = "Network matching mode",
				top_margin = 6,
				visible = not is_provide_only,
			}, {
				gui.Dropdown(
					{
						tooltip = "Determines how network matching is performed for this order.\n\n[font=default-bold]OR[/font]: If the requesting order has any networks in common with the providing order, it is considered a match.\n[font=default-bold]AND[/font]: The requesting order must share ALL of its networks with the providing order to be considered a match.\n\nThe requesting order always determines the network matching mode.",
					},
					combinator,
					"order_" .. arity .. "_network_matching_mode",
					andor_dropdown_items
				),
			}),
			gui.InnerHeading({
				caption = "Flags",
				visible = not is_provide_only,
			}),
			gui.Checkbox(
				"Stacked requests",
				"If checked, all requests will be interpreted as stacks of items rather than item counts.",
				combinator,
				"order_" .. arity .. "_stacked_requests",
				nil,
				nil,
				nil,
				is_provide_only
			),
			gui.Checkbox(
				"Mitigate starvation for requested items",
				"When checked, requests for this order will receive special handling to prevent starvation. Uncheck for orders to which starvation doesn't apply, such as void or dump orders.",
				combinator,
				"order_" .. arity .. "_no_starvation",
				true,
				nil,
				nil,
				is_provide_only
			),
		})
	end,
})
