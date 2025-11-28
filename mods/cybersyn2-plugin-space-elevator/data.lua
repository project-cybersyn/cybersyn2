local plugins = data.raw["mod-data"]["cybersyn2"].data.route_plugins

plugins["space-elevator"] = {
	reachable_callback = {
		"cybersyn2-plugin-space-elevator",
		"reachable_callback",
	},
	route_callback = { "cybersyn2-plugin-space-elevator", "route_callback" },
	train_topology_callback = {
		"cybersyn2-plugin-space-elevator",
		"train_topology_callback",
	},
}
