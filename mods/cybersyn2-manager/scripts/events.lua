local event = require("__cybersyn2__.lib.events").create_event

on_inspector_selected, raise_inspector_selected = event("on_inspector_selected", "EventData.on_player_selected_area",
	"nil", "nil",
	"nil", "nil")
