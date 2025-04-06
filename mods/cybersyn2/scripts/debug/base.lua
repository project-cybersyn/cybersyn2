--------------------------------------------------------------------------------
-- Debugging facilities
--------------------------------------------------------------------------------

local strace_lib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2

local strace = strace_lib.strace
local strace_filter = strace_lib.filter
local stringify = strace_lib.stringify
local floor = math.floor
local select = _G.select
local tconcat = table.concat
local strformat = string.format
local level_str = strace_lib.level_to_string

---Saved game state for debug modes.
---@class Cybersyn.Internal.DebugState
---@field public overlay Cybersyn.Internal.DebugOverlayState?
---@field public strace_always_level? int
---@field public strace_level? int
---@field public strace_filter? table
---@field public strace_whitelist? boolean

--------------------------------------------------------------------------------
-- Strace handlers for libraries
--------------------------------------------------------------------------------

local relm = require("__cybersyn2__.lib.relm")
relm.configure({ strace = strace })

local events = require("__cybersyn2__.lib.events")
events.set_strace_handler(strace)

local scheduler = require("__cybersyn2__.lib.scheduler")
scheduler.set_strace_handler(strace)

--------------------------------------------------------------------------------
-- Strace logging setup.
--------------------------------------------------------------------------------

local print_opts = {
	game_state = false,
	skip = defines.print_skip.never,
	sound = defines.print_sound.never,
}

local function print_strace(level, ...)
	if not game then return end
	local str
	local n = select("#", ...)
	if n == 1 then
		str = stringify(...)
	else
		local accum = {}
		for i = 1, n do
			local val = select(i, ...)
			if val ~= "message" then accum[#accum + 1] = stringify(val) end
		end
		str = tconcat(accum, " ")
	end

	local t = game.tick
	local s = floor((t / 60) % 60)
	local m = floor((t / 3600) % 60)
	local h = floor((t / 216000))
	game.print(
		strformat(
			"[%04d:%02d:%02d] %s %s",
			h,
			m,
			s,
			level_str[level] or "UNKNOWN",
			str
		),
		print_opts
	)
end

---@param state Cybersyn.Internal.DebugState
local function setup_strace(state)
	local base_level = state.strace_level
	-- XXX: debug only, remove for release
	if not base_level then base_level = strace_lib.DEBUG end
	local always_level = state.strace_always_level or strace_lib.MAX_LEVEL
	local filter = state.strace_filter
	local whitelist = not not state.strace_whitelist
	if not base_level or base_level >= strace_lib.MAX_LEVEL then
		strace_lib.set_handler(nil)
	else
		if filter and next(filter) then
			strace_lib.set_handler(function(level, ...)
				if level < base_level then return end
				if
					level >= always_level or strace_filter(whitelist, filter, level, ...)
				then
					return print_strace(level, ...)
				end
			end)
		else
			strace_lib.set_handler(function(level, ...)
				if level >= base_level then return print_strace(level, ...) end
			end)
		end
	end
end

cs2.on_load(function() setup_strace(storage.debug_state) end)

---Set parameters for strace messages to be printed to console.
---@param level int?
---@param always_level int?
---@param filter table?
---@param whitelist boolean?
function _G.cs2.debug.set_strace(level, always_level, filter, whitelist)
	local debug_state = storage.debug_state
	debug_state.strace_level = level
	debug_state.strace_always_level = always_level
	debug_state.strace_filter = filter
	debug_state.strace_whitelist = whitelist
	setup_strace(debug_state)
end
