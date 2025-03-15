--------------------------------------------------------------------------------
-- Database of combinator settings.
--------------------------------------------------------------------------------

local bit_extract = bit32.extract
local bit_replace = bit32.replace

---Reference that can be used to manipulate the settings of a combinator.
---@class (exact) Cybersyn.Combinator.Settings: Cybersyn.Combinator.Ephemeral

---@param combinator Cybersyn.Combinator.Ephemeral
---@return Cybersyn.Combinator.Settings
function combinator_api.get_combinator_settings(combinator)
	return combinator --[[@as Cybersyn.Combinator.Settings]]
end

---@alias Cybersyn.Combinator.SettingReader fun(definition: Cybersyn.Combinator.SettingDefinition, settings: Cybersyn.Combinator.Settings): any Reads a setting from a combinator. `nil` return value indicates the setting was absent.
---@alias Cybersyn.Combinator.SettingWriter fun(definition: Cybersyn.Combinator.SettingDefinition, settings: Cybersyn.Combinator.Settings, value: any): boolean Writes a setting to a combinator. Returns `true` if the write was successful.

---@class Cybersyn.Combinator.SettingDefinition Definition of a setting that can be stored on a Cybersyn combinator.
---@field public name string The unique name of the setting.
---@field public reader Cybersyn.Combinator.SettingReader The function used to read this setting from a combinator.
---@field public writer Cybersyn.Combinator.SettingWriter? The function used to write this setting to a combinator.

---Global table of settings
---@type table<string, Cybersyn.Combinator.SettingDefinition>
combinator_settings = {}

---Read the value of a combinator setting.
---@param combinator Cybersyn.Combinator.Settings
---@param setting Cybersyn.Combinator.SettingDefinition
---@return any value The value of the setting.
function combinator_api.read_setting(combinator, setting)
	return setting.reader(setting, combinator)
end

---Change the value of a combinator setting.
---@param combinator Cybersyn.Combinator.Settings
---@param setting Cybersyn.Combinator.SettingDefinition
---@param value any
---@param skip_event boolean? If `true`, the setting changed event will not be raised.
---@return boolean was_written `true` if a changed value was written.
function combinator_api.write_setting(combinator, setting, value, skip_event)
	local old = setting.reader(setting, combinator)
	if old == value then return false end
	local writer = setting.writer
	if not writer then return false end
	local written = writer(setting, combinator, value)
	if written and (not skip_event) then
		raise_combinator_or_ghost_setting_changed(combinator, setting.name, value, old)
	end
	return written
end

---Create a new combinator setting definition.
---@param definition Cybersyn.Combinator.SettingDefinition
function combinator_api.register_setting(definition)
	local name = definition.name
	if combinator_settings[name] then
		return false
	end
	combinator_settings[name] = definition
	return true
end

---Utility function for creating a boolean setting stored in a bitfield key.
---@param setting_name string The name of the setting.
---@param bitfield_key string The key of the bitfield to read from and write to.
---@param bit_index uint The index of the bit to read from and write to.
---@return Cybersyn.Combinator.SettingDefinition
function combinator_api.make_flag_setting(setting_name, bitfield_key, bit_index)
	return {
		name = setting_name,
		reader = function(definition, settings)
			local bits = combinator_api.get_raw_value(settings.entity, bitfield_key)
			if type(bits) ~= "number" then bits = bits and 1 or 0 end
			return (bit_extract(bits, bit_index, 1) ~= 0)
		end,
		writer = function(definition, settings, new_value)
			local bits = combinator_api.get_raw_value(settings.entity, bitfield_key)
			if type(bits) ~= "number" then bits = bits and 1 or 0 end
			local new_bits = bit_replace(bits, new_value and 1 or 0, bit_index, 1)
			return combinator_api.set_raw_value(settings.entity, bitfield_key, new_bits)
		end,
	}
end

---Utility function for creating a setting that stores a value directly.
---@param setting_name string The name of the setting.
---@param key string The key of the value to read from and write to.
---@return Cybersyn.Combinator.SettingDefinition
function combinator_api.make_raw_setting(setting_name, key)
	return {
		name = setting_name,
		reader = function(definition, settings)
			return combinator_api.get_raw_value(settings.entity, key)
		end,
		writer = function(definition, settings, new_value)
			return combinator_api.set_raw_value(settings.entity, key, new_value)
		end,
	}
end

combinator_api.register_setting({
	name = "mode",
	reader = function(definition, settings)
		return combinator_api.get_raw_value(settings.entity, "mode") or "unknown"
	end,
	writer = function(definition, settings, new_mode)
		if not combinator_api.get_combinator_mode(new_mode) then
			return false
		end
		return combinator_api.set_raw_value(settings.entity, "mode", new_mode)
	end,
})
