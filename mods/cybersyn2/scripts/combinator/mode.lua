--------------------------------------------------------------------------------
-- Combinator modes
--------------------------------------------------------------------------------

local cs2 = _G.cs2
local events = require("lib.core.event")

local modes = _G.cs2.combinator_modes

---@type string[]
local mode_list = {}

---Register a new combinator mode.
---@param mode_definition Cybersyn.Combinator.ModeDefinition
function _G.cs2.register_combinator_mode(mode_definition)
	local name = mode_definition.name
	if (not name) or modes[name] then return false end
	modes[name] = mode_definition
	table.insert(mode_list, name)
	return true
end

---Get a list of name keys of all combinator modes.
function _G.cs2.get_combinator_mode_list() return mode_list end

---Get a combinator mode by name.
---@param name string
function _G.cs2.get_combinator_mode(name) return modes[name or ""] end

--------------------------------------------------------------------------------
-- Pull mode into combinator data
--------------------------------------------------------------------------------

events.bind(
	"cs2.combinator_settings_changed",
	---@param combinator Cybersyn.Combinator
	function(combinator, key, value)
		if (not key) or key == "mode" then
			local prev_mode = combinator.mode
			local new_mode = value
			if prev_mode ~= new_mode then
				combinator.mode = new_mode
				combinator:clear_outputs()
			end
		end
	end,
	true
)
