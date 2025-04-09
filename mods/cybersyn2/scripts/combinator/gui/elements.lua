--------------------------------------------------------------------------------
-- Reusable Relm elements for combinator gui
--------------------------------------------------------------------------------

local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local cs2 = _G.cs2
local Pr = relm.Primitive
local HF = ultros.HFlow

---An `ultros.Checkbox` that reads from and writes to a combinator
---setting automatically.
---@param caption LocalisedString
---@param tooltip LocalisedString?
function _G.cs2.gui.Checkbox(caption, tooltip, combinator, setting, inverse)
	local value = combinator:read_setting(setting)
	if inverse then value = not value end
	return ultros.Checkbox({
		caption = caption,
		tooltip = tooltip,
		value = value,
		on_change = function(_, state)
			local new_state = state
			if inverse then new_state = not state end
			combinator:write_setting(setting, new_state)
		end,
	})
end

---An `ultros.SignalPicker` that reads/writes a `SignalID` to/from a
---combinator setting.
function _G.cs2.gui.AnySignalPicker(combinator, setting)
	return ultros.SignalPicker({
		value = combinator:read_setting(setting),
		on_change = function(_, signal)
			if signal and signal.type == nil then signal.type = "item" end
			combinator:write_setting(setting, signal)
		end,
	})
end

---An `ultros.SignalPicker` that reads/writes a `SignalID` to/from a
---combinator setting. Only allows valid network signals.
function _G.cs2.gui.NetworkSignalPicker(combinator, setting)
	return ultros.SignalPicker({
		virtual_signal = combinator:read_setting(setting),
		on_change = function(_, signal, elem)
			if not signal then return combinator:write_setting(setting, nil) end
			if
				signal.type == "virtual"
				and not cs2.CONFIGURATION_VIRTUAL_SIGNAL_SET[signal.name]
			then
				local stored = signal.name
				if
					signal.name == "signal-everything"
					or signal.name == "signal-anything"
					or signal.name == "signal-each"
				then
					stored = "signal-each"
				end

				combinator:write_setting(setting, stored)
			else
				game.print(
					"Invalid signal type. Please select a non-configuration virtual signal.",
					{
						color = { 255, 128, 0 },
						skip = defines.print_skip.never,
						sound = defines.print_sound.always,
					}
				)
				elem.elem_value = nil
			end
		end,
	})
end

function _G.cs2.gui.Dropdown(user_props, combinator, setting, options)
	local value = combinator:read_setting(setting)
	local props = ultros.assign({
		value = value,
		options = options,
		on_change = function(_, selected)
			combinator:write_setting(setting, selected)
		end,
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
function _G.cs2.gui.Switch(tooltip, is_tristate, L, R, combinator, setting)
	return ultros.Switch({
		left_label_caption = L,
		right_label_caption = R,
		allow_none_state = is_tristate,
		value = combinator:read_setting(setting),
		on_change = function(_, state) combinator:write_setting(setting, state) end,
	})
end

_G.cs2.gui.Input = relm.define_element({
	name = "CombinatorGui.Input",
	render = function(props, state)
		local dirty = not not (state and state.dirty)
		local value = props.combinator:read_setting(props.setting)
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
			props.combinator:write_setting(props.setting, message.value)
			relm.set_state(me, { dirty = false })
			return true
		else
			return false
		end
	end,
})
