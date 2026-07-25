---@diagnostic disable-next-line: unresolved-require
local things = require("__0-things__.client.client") --[[@as things.client]]

data:extend({
	{
		type = "custom-event",
		name = "cybersyn2-prod-train",
	},
	{
		type = "mod-data",
		name = "cybersyn2",
		data = {
			route_plugins = {},
			custom_stop_names = {},
			busy_plugins = {},
			node_topology_plugins = {},
			vehicle_topology_plugins = {},
			node_match_veto_plugins = {},
		},
	},
})

--------------------------------------------------------------------------------
-- Custom circuit detector
--------------------------------------------------------------------------------

local trigger = things.combinators_v1.create_custom_trigger_prototype(
	"cybersyn2-circuit-trigger"
)
trigger.name = "cybersyn2-circuit-trigger"
data:extend({
	trigger,
	{ type = "custom-event", name = "cybersyn2-circuit-trigger" },
})
