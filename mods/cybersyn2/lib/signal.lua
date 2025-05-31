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
local strformat = string.format
local type = _G.type
local abs = math.abs
local floor = math.floor
local tostring = _G.tostring

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

local parameter_names = {
	["parameter-0"] = true,
	["parameter-1"] = true,
	["parameter-2"] = true,
	["parameter-3"] = true,
	["parameter-4"] = true,
	["parameter-5"] = true,
	["parameter-6"] = true,
	["parameter-7"] = true,
	["parameter-8"] = true,
	["parameter-9"] = true,
}

---Cache mapping keys to signals
---@type table<SignalKey, SignalID>
local key_to_sig = {}

---Cache of signal keys to virtual/product
---@type table<SignalKey, boolean>
local key_v = {}

---Cache mapping item signal keys to stack sizes
---@type table<SignalKey, uint>
local key_stack_size = {}

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
		signal.quality = quality_name -- don't cache signal qualities as prototypes
		key_to_sig[key] = signal
		if not parameter_names[key] then key_v[key] = false end
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
			if not parameter_names[key] then key_v[key] = false end
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
	if parameter_names[key] then return false end
	local sig = key_to_signal(key)
	return sig.type == "item" or sig.type == "fluid"
end
lib.key_is_cargo = key_is_cargo

---Determine if this signal key represents a fluid signal.
---@param key SignalKey
local function key_is_fluid(key)
	local s = key_to_signal(key)
	if s then return s.type == "fluid" end
end
lib.key_is_fluid = key_is_fluid

---Classify keys relevant to Cybersyn input mechanisms.
---@return "cargo"|"virtual"|nil genus Genus of the key
---@return "item"|"fluid"|nil species For `cargo` keys, species of the cargo.
local function classify_key(key)
	if parameter_names[key] then return end
	local sig = key_to_signal(key)
	if sig then
		if sig.type == "item" or sig.type == "fluid" then
			return "cargo", sig.type --[[@as "item"|"fluid"]]
		elseif sig.type == "virtual" then
			return "virtual", nil
		end
	end
end
lib.classify_key = classify_key

---@param key SignalKey
local function key_to_richtext(key)
	local sig = key_to_signal(key)
	if not sig then return "(INVALID SIGNAL KEY '" .. key .. "')" end
	if sig.type == "item" then
		if sig.quality then
			return strformat("[item=%s,quality=%s]", sig.name, sig.quality)
		else
			return strformat("[item=%s]", sig.name)
		end
	elseif sig.type == "fluid" then
		return strformat("[fluid=%s]", sig.name)
	elseif sig.type == "virtual" then
		return strformat("[virtual-signal=%s]", sig.name)
	end
end
lib.key_to_richtext = key_to_richtext

---@param key SignalKey
local function key_to_stacksize(key)
	if not key then return nil end
	local sz = key_stack_size[key]
	if sz then return sz end
	local sig = key_to_signal(key)
	if sig and sig.type == "item" then
		sz = prototypes.item[sig.name].stack_size
		key_stack_size[key] = sz
		return sz
	else
		return nil
	end
end
lib.key_to_stacksize = key_to_stacksize

---Format the count of a signal as a small SI string for display on buttons.
---@param count int
---@return string
function lib.format_signal_count(count)
	local function si_format(divisor, si_symbol)
		if abs(floor(count / divisor)) >= 10 then
			count = floor(count / divisor)
			return strformat("%.0f%s", count, si_symbol)
		else
			count = floor(count / (divisor / 10)) / 10
			return strformat("%.1f%s", count, si_symbol)
		end
	end

	local absv = abs(count)
	return -- signals are 32bit integers so Giga is enough
		absv >= 1e9 and si_format(1e9, "G") or absv >= 1e6 and si_format(
		1e6,
		"M"
	) or absv >= 1e3 and si_format(1e3, "k") or tostring(count)
end

---Convert an array of signals to a table of signal counts.
---@param signals Signal[]
---@return SignalCounts
function lib.signals_to_signal_counts(signals)
	local counts = {}
	for i = 1, #signals do
		local signal = signals[i]
		counts[signal_to_key(signal.signal)] = signal.count
	end
	return counts
end

return lib
