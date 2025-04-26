if ... ~= "__cybersyn2__.lib.logging" then
	return require("__cybersyn2__.lib.logging")
end

local strace_lib = require("__cybersyn2__.lib.strace")

local strace = strace_lib.strace
local TRACE = strace_lib.TRACE
local DEBUG = strace_lib.DEBUG
local WARN = strace_lib.WARN
local ERROR = strace_lib.ERROR
local INFO = strace_lib.INFO
local tconcat = table.concat

local SERPENT_LINE_ARGS = { maxlevel = 5, maxnum = 20, nocode = true }
local mod_name = script.mod_name

local lib = {}

---Convert values to strings after the fashion of the `log` functions.
---@deprecated
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
	elseif val_t == "function" then
		return "(function)"
	else
		return serpent.line(val, SERPENT_LINE_ARGS)
	end
end
lib.stringify = stringify

---@param level int
---@param category string?
---@param filter any
---@param msg string
local function log(level, category, filter, msg, ...)
	if not game then return end
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

---@deprecated Use strace
function lib.trace(msg, ...)
	return strace(
		TRACE,
		"mod",
		mod_name,
		"logging",
		"deprecated",
		"message",
		msg,
		...
	)
end

---@deprecated Use strace
function lib.debug(msg, ...)
	return strace(
		DEBUG,
		"mod",
		mod_name,
		"logging",
		"deprecated",
		"message",
		msg,
		...
	)
end

---@deprecated Use strace
function lib.info(msg, ...)
	return strace(
		INFO,
		"mod",
		mod_name,
		"logging",
		"deprecated",
		"message",
		msg,
		...
	)
end

---@deprecated Use strace
function lib.warn(msg, ...)
	return strace(
		WARN,
		"mod",
		mod_name,
		"logging",
		"deprecated",
		"message",
		msg,
		...
	)
end

---@deprecated Use strace
function lib.error(msg, ...)
	return strace(
		ERROR,
		"mod",
		mod_name,
		"logging",
		"deprecated",
		"message",
		msg,
		...
	)
end

return lib
