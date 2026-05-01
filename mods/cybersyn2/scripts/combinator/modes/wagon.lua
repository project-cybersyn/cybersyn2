--------------------------------------------------------------------------------
-- Wagon mode (deprecated)
--------------------------------------------------------------------------------

local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local cs2 = _G.cs2

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Wagon",
	render = function(props)
		return ultros.WellSection(
			{ caption = { "cybersyn2-combinator-modes-labels.deprecated" } },
			{
				ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-deprecated.desc" }),
			}
		)
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Wagon.Help",
	render = function(props) end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "wagon",
	localized_string = "cybersyn2-combinator-modes.wagon",
	settings_element = "CombinatorGui.Mode.Wagon",
	help_element = "CombinatorGui.Mode.Wagon.Help",
	is_output = true,
	deprecated = true,
})
