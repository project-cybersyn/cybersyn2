-- Reset relm
local relm = require("lib.core.relm.relm")
relm.destroy_all_roots()

-- Clear old gui state
for _, state in pairs(storage.players) do
	state.open_combinator = nil
	state.combinator_gui_root = nil
end
