-- Shared library for forward and reverse lookups of signals from hash keys.

if ... ~= "__cybersyn2__.lib.signal-keys" then
	return require("__cybersyn2__.lib.signal-keys")
end

---@alias Cybersyn.SignalKey string A string identifying a particular SignalID.

local lib = {}

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

-- Cache mapping keys to signals
local key_to_sig = {}

---@param signal SignalID
---@return Cybersyn.SignalKey
local function signal_to_key(signal)
	local quality_name
	if not signal.quality then
		quality_name = nil
	elseif type(signal.quality) == "string" then
		quality_name = signal.quality
	else
		quality_name = signal.quality.name
	end
	local key = nil
	if quality_name == nil or quality_name == "normal" then
		key = signal.name
	else
		key = signal.name .. "|" .. quality_name
	end
---@diagnostic disable-next-line: need-check-nil
	key_to_sig[key] = signal
---@diagnostic disable-next-line: return-type-mismatch
	return key
end

local function key_to_signal(key)
	local signal = key_to_sig[key]
	if signal then return signal end
	-- Cache miss so we have to reconstruct the signal
end

-- TODO: not done

return lib
