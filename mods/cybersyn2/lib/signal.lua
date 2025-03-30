---@diagnostic disable: need-check-nil
--------------------------------------------------------------------------------
-- Shared utility library for working with Factorio signals, including hashing
-- signals to and from strings.
--------------------------------------------------------------------------------

if ... ~= "__cybersyn2__.lib.signal" then
	return require("__cybersyn2__.lib.signal")
end

local strsub = string.sub
local strfind = string.find
local type = _G.type

---@alias SignalKey string A string identifying a particular SignalID.

---@alias SignalCounts table<SignalKey, int> Signals and associated counts.

local lib = {}

---Get the `string` quality name from a `QualityID` value.
---@param quality_id QualityID?
---@return string?
local function get_quality_name(quality_id)
	if quality_id == nil then
		return nil
	elseif type(quality_id) == "string" then
		return quality_id
	else
		return quality_id.name
	end
end
lib.get_quality_name = get_quality_name

---Get the type of a signal from the name of an item, fluid, virtual_signal,
---entity, recipe, space_location, or asteroid_chunk, prioritizing in that
---order. This function forces Factorio to instantiate a bunch of prototypes
---and should therefore be avoided.
---@param name string
---@return string?
local function get_signal_type_from_name(name)
	if prototypes.item[name] ~= nil then
		return "item"
	elseif prototypes.fluid[name] ~= nil then
		return "fluid"
	elseif prototypes.virtual_signal[name] ~= nil then
		return "virtual"
	elseif prototypes.entity[name] ~= nil then
		return "entity"
	elseif prototypes.recipe[name] ~= nil then
		return "recipe"
	elseif prototypes.space_location[name] ~= nil then
		return "space-location"
	elseif prototypes.asteroid_chunk[name] ~= nil then
		return "asteroid-chunk"
	elseif prototypes.quality[name] ~= nil then
		return "quality"
	else
		return nil
	end
end

---Cache mapping keys to signals
---@type table<SignalKey, SignalID>
local key_to_sig = {}

---Cache of signal keys to virtual/product
---@type table<SignalKey, boolean>
local key_v = {}

---Convert a signal to a key.
---@param signal SignalID
---@return SignalKey
local function signal_to_key(signal)
	local quality_name
	local quality = signal.quality
	local stype = signal.type
	if not quality then
		quality_name = nil
	elseif type(quality) == "string" then
		quality_name = quality
	else
		quality_name = quality.name
	end
	-- TODO: benchmark caching this in a 2d hash like hash[quality][type]
	---@type string
	local key
	if quality_name == nil or quality_name == "normal" then
		key = signal.name
	else
		key = signal.name .. "|" .. quality_name
	end
	if stype == "item" or stype == "fluid" then
		key_to_sig[key] = signal
		key_v[key] = false
	elseif stype == "virtual" then
		key_to_sig[key] = signal
		key_v[key] = true
	end
	return key --[[@as SignalKey]]
end
lib.signal_to_key = signal_to_key

---@param key string
---@return string? name
---@return string? type
---@return string? quality
local function missed_key_to_signal_parts(key)
	local index = strfind(key, "|", 1, true)
	---@type string
	local name
	---@type string?
	local quality
	if index then
		name = strsub(key, 1, index - 1)
		quality = strsub(key, index + 1)
	else
		name = key
	end
	local ty = get_signal_type_from_name(name)
	if ty == nil then return nil end
	return name, ty, quality
end

---Convert a key to a signal.
---@param key SignalKey
---@return SignalID?
local function key_to_signal(key)
	local signal = key_to_sig[key]
	if signal then return signal end
	-- Cache miss so we have to reconstruct the signal
	local name, ty, quality = missed_key_to_signal_parts(key)
	if name then
		signal = { name = name, type = ty, quality = quality }
		if ty == "item" or ty == "fluid" then
			key_to_sig[key] = signal
			key_v[key] = false
		elseif ty == "virtual" then
			key_to_sig[key] = signal
			key_v[key] = true
		end
		return signal
	else
		return nil
	end
end
lib.key_to_signal = key_to_signal

---@param key SignalKey
local function key_is_virtual(key)
	local verdict = key_v[key]
	if verdict ~= nil then return verdict end
	local sig = key_to_signal(key)
	return sig.type == "virtual"
end
lib.key_is_virtual = key_is_virtual

---@param key SignalKey
local function key_is_cargo(key)
	local verdict = key_v[key]
	if verdict ~= nil then return not verdict end
	local sig = key_to_signal(key)
	return sig.type == "item" or sig.type == "fluid"
end
lib.key_is_cargo = key_is_cargo

---@param key SignalKey
local function key_is_fluid(key)
	local s = key_to_signal(key)
	if s then return s.type == "fluid" end
end
lib.key_is_fluid = key_is_fluid

return lib
