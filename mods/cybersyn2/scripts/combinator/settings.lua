--------------------------------------------------------------------------------
-- Combinator settings.
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local cs2 = _G.cs2
local events = require("lib.core.event")
local tlib = require("lib.core.table")
local strace = require("lib.core.strace")

local EMPTY_STRICT = tlib.EMPTY_STRICT
local bit_extract = bit32.extract
local bit_replace = bit32.replace

---@class Cybersyn.Combinator
---@field public tag_cache? Tags The cached tags for this combinator.
local Combinator = cs2.Combinator

---@return Tags
function Combinator:get_tags()
	local tc = self.tag_cache
	if tc then return tc end
	local _, thing = remote.call("things", "get", self.id)
	if thing then
		self.tag_cache = thing.tags
		return thing.tags or EMPTY_STRICT
	end
	return EMPTY_STRICT
end

--------------------------------------------------------------------------------
-- Setting registration
--------------------------------------------------------------------------------

---@param combinator Cybersyn.Combinator
---@param key string
---@param value AnyBasic
local function set_tag(combinator, key, value)
	local tag_cache = combinator.tag_cache
	if tag_cache then tag_cache[key] = value end
	remote.call("things", "set_tag", combinator.id, key, value)
end

local function raise_event(combinator, setting_name, new_value, old_value)
	events.raise(
		"cs2.combinator_settings_changed",
		combinator,
		setting_name,
		new_value,
		old_value
	)
	cs2.raise_combinator_setting_changed(
		combinator,
		setting_name,
		new_value,
		old_value
	)
end

---Register a flag combinator setting
---@param setting_name string The name of the setting.
---@param bitfield_key string The key of the bitfield to read from and write to.
---@param bit_index uint The index of the bit to read from and write to.
function _G.cs2.register_flag_setting(setting_name, bitfield_key, bit_index)
	Combinator["get_" .. setting_name] = function(self)
		local tags = self:get_tags()
		local bits = tags[bitfield_key]
		if type(bits) ~= "number" then bits = bits and 1 or 0 end
		return (bit_extract(bits, bit_index, 1) ~= 0)
	end
	Combinator["set_" .. setting_name] = function(self, new_value)
		local tags = self:get_tags()
		local bits = tags[bitfield_key]
		if type(bits) ~= "number" then bits = bits and 1 or 0 end
		local new_bits = bit_replace(bits, new_value and 1 or 0, bit_index, 1) --[[@as int]]
		set_tag(self, bitfield_key, new_bits)
		raise_event(self, setting_name, new_value)
	end
end

---Register a raw combinator setting
---@param setting_name string The name of the setting.
---@param key string The key of the value to read from and write to.
---@param default any? The default value if the setting is `nil` or absent.
function _G.cs2.register_raw_setting(setting_name, key, default)
	Combinator["get_" .. setting_name] = function(self)
		local tags = self:get_tags()
		return tags[key] or default
	end
	Combinator["set_" .. setting_name] = function(self, new_value)
		local tags = self:get_tags()
		local old_value = tags[key] or default
		if old_value == new_value then return false end
		set_tag(self, key, new_value)
		raise_event(self, key, new_value, old_value)
	end
end

--------------------------------------------------------------------------------
-- The mode setting.
--------------------------------------------------------------------------------

---@param new_mode string
function Combinator:set_mode(new_mode)
	if not cs2.get_combinator_mode(new_mode) then return false end
	local tags = self:get_tags()
	local old_mode = tags.mode
	if old_mode == new_mode then return false end
	set_tag(self, "mode", new_mode)
	raise_event(self, "mode", new_mode, old_mode)
end

--------------------------------------------------------------------------------
-- Event propagation
--------------------------------------------------------------------------------

events.bind(
	"cybersyn2-combinator-on_tags_changed",
	---@param event things.EventData.on_tags_changed
	function(event)
		local combinator = storage.combinators[event.thing.id]
		if not combinator then
			strace.warn(
				"on_tags_changed: Ref integrity failure: combinator not found for thing id",
				event.thing.id
			)
			return
		end
		combinator.tag_cache = event.new_tags
		if event.cause == "engine" then
			events.raise("cs2.combinator_settings_changed", combinator, nil, nil)
			cs2.raise_combinator_setting_changed(combinator, nil, nil)
		end
	end
)
