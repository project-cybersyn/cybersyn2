if ... ~= "__cybersyn2__.lib.logging" then
	return require("__cybersyn2__.lib.logging")
end

local tconcat = table.concat
local SERPENT_LINE_ARGS = { maxlevel = 5, maxnum = 20 }

local lib = {}

---@enum Log.Level
local log_level = {
	["trace"] = 1,
	["debug"] = 2,
	["info"] = 3,
	["warn"] = 4,
	["error"] = 5,
}
lib.level = log_level

---Convert values to strings after the fashion of the `log` functions.
---@param val any
---@return string
local function stringify(val)
	local val_t = type(val)
	if
		val_t == "nil"
		or val_t == "number"
		or val_t == "string"
		or val_t == "boolean"
	then
		return tostring(val)
	else
		return serpent.line(val, SERPENT_LINE_ARGS)
	end
end
lib.stringify = stringify

---@param level Log.Level
---@param category string?
---@param filter any
---@param msg string
local function log(level, category, filter, msg, ...)
	if not game then
		return
	end
	local str = { msg }
	for i = 1, select("#", ...) do
		local val = select(i, ...)
		str[#str + 1] = stringify(val)
	end
	game.print(tconcat(str, " "), {
		skip = defines.print_skip.never,
		sound = defines.print_sound.never,
		game_state = false,
	})
end
lib.log = log

function lib.trace(msg, ...)
	return log(log_level.trace, nil, nil, msg, ...)
end

function lib.debug(msg, ...)
	return log(log_level.debug, nil, nil, msg, ...)
end

function lib.info(msg, ...)
	return log(log_level.info, nil, nil, msg, ...)
end

function lib.warn(msg, ...)
	return log(log_level.warn, nil, nil, msg, ...)
end

function lib.error(msg, ...)
	return log(log_level.error, nil, nil, msg, ...)
end

local once_keys = {}

---Log something exactly once per Lua session based on key.
---@param level Log.Level
---@param once_key string
---@param category string?
---@param filter any
---@param msg string
function lib.once(level, once_key, category, filter, msg, ...)
	if once_keys[once_key or ""] then
		return
	end
	once_keys[once_key or ""] = true
	return log(level, category, filter, msg, ...)
end

return lib
