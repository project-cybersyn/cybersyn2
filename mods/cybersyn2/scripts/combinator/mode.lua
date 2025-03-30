--------------------------------------------------------------------------------
-- Combinator modes
--------------------------------------------------------------------------------

local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api

---@class (exact) Cybersyn.Combinator.ModeDefinition
---@field name string The name of the mode, which must be unique. Used as the internal storage key for the mode.
---@field localized_string string The Factorio localized string for the mode.
---@field settings_element string? Name of a Relm element to use as the GUI settings element for this mode. Will be passed the active combinator as a `combinator` prop. If not provided, a noninteractive placeholder element will be rendered.
---@field help_element string? Name of a Relm element to use as the GUI help element for this mode. Will be passed the active combinator as a `combinator` prop. If not provided, a noninteractive placeholder element will be rendered.
---@field is_input boolean? `true` if the input signals of a combinator in this mode should be read during `poll_combinators`.

---@type {[string]: Cybersyn.Combinator.ModeDefinition}
_G.cs2.combinator_modes = {}
local modes = _G.cs2.combinator_modes

---@type string[]
local mode_list = {}

---Register a new combinator mode.
---@param mode_definition Cybersyn.Combinator.ModeDefinition
function _G.cs2.combinator_api.register_combinator_mode(mode_definition)
	local name = mode_definition.name
	if (not name) or modes[name] then
		return false
	end
	modes[name] = mode_definition
	table.insert(mode_list, name)
	return true
end

---Get a list of name keys of all combinator modes.
function _G.cs2.combinator_api.get_combinator_mode_list()
	return mode_list
end

---Get a combinator mode by name.
---@param name string
function _G.cs2.combinator_api.get_combinator_mode(name)
	return modes[name or ""]
end

--------------------------------------------------------------------------------
-- Pull mode into combinator data
--------------------------------------------------------------------------------

cs2.on_combinator_setting_changed(function(combinator, setting)
	if (not setting) or setting == "mode" then
		combinator.mode = combinator_api.get_raw_value(combinator.entity, "mode") --[[@as string?]]
	end
end, true)

cs2.on_combinator_created(function(combinator)
	combinator.mode = combinator_api.get_raw_value(combinator.entity, "mode") --[[@as string?]]
end, true)
