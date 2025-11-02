local events = require("__cybersyn2__.lib.core.event")
local strace = require("__cybersyn2__.lib.core.strace")

local SE_ELEVATOR_ORBIT_SUFFIX = " ↓"
local SE_ELEVATOR_PLANET_SUFFIX = " ↑"
local SE_ELEVATOR_SUFFIX_LENGTH = #SE_ELEVATOR_ORBIT_SUFFIX
local SE_ELEVATOR_PREFIX = "[img=entity/se-space-elevator]  "
local SE_ELEVATOR_PREFIX_LENGTH = #SE_ELEVATOR_PREFIX

strace.set_handler(strace.standard_log_handler)

require("storage")

local function on_train_teleport_started(event)
	strace.debug("on_train_teleport_started", event)
end

local function on_train_teleport_finished(event)
	strace.debug("on_train_teleport_finished", event)
end

local function bind_se_events()
	if not remote.interfaces["space-exploration"] then
		strace.warn(
			"Space Exploration mod not found; cybersyn2-plugin-space-elevator will not function."
		)
		return
	end
	strace.info(
		"Space Exploration mod detected; initializing cybersyn2-plugin-space-elevator."
	)

	events.bind(
		remote.call("space-exploration", "get_on_train_teleport_finished_event"),
		on_train_teleport_finished
	)
	events.bind(
		remote.call("space-exploration", "get_on_train_teleport_started_event"),
		on_train_teleport_started
	)
end

events.bind("on_init", bind_se_events)
events.bind("on_load", bind_se_events)
