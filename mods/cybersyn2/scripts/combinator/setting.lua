--------------------------------------------------------------------------------
-- Database of combinator settings.
--------------------------------------------------------------------------------

local cs2 = _G.cs2

local bit_extract = bit32.extract
local bit_replace = bit32.replace

---Create a new combinator setting definition.
---@param definition Cybersyn.Combinator.SettingDefinition
function _G.cs2.register_combinator_setting(definition)
	local name = definition.name
	if (not name) or cs2.combinator_settings[name] then
		-- Crash here so dev knows they need to use a unique name.
		error("Duplicate or missing combinator setting name " .. tostring(name))
		return false
	end
	cs2.combinator_settings[name] = definition
	return true
end

---Utility function for creating a boolean setting stored in a bitfield key.
---@param setting_name string The name of the setting.
---@param bitfield_key string The key of the bitfield to read from and write to.
---@param bit_index uint The index of the bit to read from and write to.
---@return Cybersyn.Combinator.SettingDefinition
function _G.cs2.lib.make_flag_setting(setting_name, bitfield_key, bit_index)
	return {
		name = setting_name,
		reader = function(_, comb)
			local bits = comb:get_raw_setting(bitfield_key)
			if type(bits) ~= "number" then bits = bits and 1 or 0 end
			return (bit_extract(bits, bit_index, 1) ~= 0)
		end,
		writer = function(_, comb, new_value)
			local bits = comb:get_raw_setting(bitfield_key)
			if type(bits) ~= "number" then bits = bits and 1 or 0 end
			local new_bits = bit_replace(bits, new_value and 1 or 0, bit_index, 1)
			return comb:set_raw_setting(bitfield_key, new_bits)
		end,
	}
end

---Utility function for creating a setting that stores a value directly.
---@param setting_name string The name of the setting.
---@param key string The key of the value to read from and write to.
---@param default any? The default value if the setting is `nil` or absent.
---@return Cybersyn.Combinator.SettingDefinition
function _G.cs2.lib.make_raw_setting(setting_name, key, default)
	return {
		name = setting_name,
		reader = function(_, comb) return comb:get_raw_setting(key) or default end,
		writer = function(_, comb, new_value)
			return comb:set_raw_value(key, new_value)
		end,
	}
end

cs2.register_combinator_setting({
	name = "mode",
	reader = function(_, comb) return comb:get_raw_setting("mode") or "unknown" end,
	writer = function(_, comb, new_mode)
		if not cs2.get_combinator_mode(new_mode) then return false end
		return comb:set_raw_setting("mode", new_mode)
	end,
})

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- When a setting is changed, if the combinator in question is real, forward the event.
cs2.on_combinator_or_ghost_setting_changed(
	function(combinator, setting_name, new_value, old_value)
		local real = storage.combinators[combinator.entity.unit_number]
		if real then
			cs2.raise_combinator_setting_changed(
				real,
				setting_name,
				new_value,
				old_value
			)
		end
	end
)
