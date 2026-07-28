local strace = require("lib.core.strace")
local cs2 = _G.cs2

local mod_settings = cs2.mod_settings

---@type table<string, fun(query: Cybersyn.QueryInput): Cybersyn.QueryResult>
cs2.query_handlers = {}

-- Things tag migration callback
function cs2.remote_api.migrate_tags_callback(tags) return tags end

-- Things initial tags callback
function cs2.remote_api.initial_tags_callback(entity)
	return cs2.DEFAULT_COMBINATOR_SETTINGS
end

---Invoked by a route plugin to hand control of a train back to Cybersyn 2
---when the plugin is done routing it. May also optionally replace the
---LuaTrain ID that Cybersyn 2 uses to track the train.
---@param delivery_id uint ID of the delivery being handed back.
---@param new_luatrain? LuaTrain A new LuaTrain object to replace the existing one.
function cs2.remote_api.route_plugin_handoff(delivery_id, new_luatrain)
	local delivery = cs2.get_delivery(delivery_id)
	if not delivery then
		strace.warn("route_plugin_handoff: Delivery ID not found:", delivery_id)
		return { code = "invalid_delivery", message = "Delivery ID not found." }
	end
	if delivery.type ~= "train" then
		strace.warn(
			"route_plugin_handoff: Delivery is not a train delivery:",
			delivery_id
		)
		return {
			code = "invalid_delivery",
			message = "Delivery is not a train delivery.",
		}
	end
	strace.info("route_plugin_handoff: Handing back delivery ID", delivery_id)
	---@cast delivery Cybersyn.TrainDelivery
	delivery:notify_plugin_handoff(new_luatrain)
	return nil
end

---@deprecated Use `retopologize()` instead.
function cs2.remote_api.rebuild_train_topologies() cs2.retopologize() end

---Force Cybersyn 2 to re-evaluate all topologies.
function cs2.remote_api.retopologize() cs2.retopologize() end

---Force a failure of a delivery.
---@param delivery_id Id ID of the delivery to fail.
---@param reason? string Optional reason for the failure.
function cs2.remote_api.fail_delivery(delivery_id, reason)
	local delivery = cs2.get_delivery(delivery_id)
	if not delivery then
		strace.warn("fail_delivery: Delivery ID not found:", delivery_id)
		return { code = "invalid_delivery", message = "Delivery ID not found." }
	end
	strace.info("fail_delivery: Failing delivery ID", delivery_id)
	delivery:fail(reason)
	return nil
end

---Create a new topology.
---@param name string Name of the topology to create.
---@param surface_indices? int[] Optional list of surface indices to associate with the topology.
---@return Id? topology_id ID of the topology with the given name, either newly created or existing. `nil` if the topology could not be created.
function cs2.remote_api.get_or_create_topology(name, surface_indices)
	local topo = cs2.get_or_create_topology_by_name(name, surface_indices)
	return topo and topo.id
end

---Get topology ID by name.
---@param name string Name of the topology to look up.
---@return Id? topology_id ID of the topology with the given name, or `nil` if no such topology exists.
function cs2.remote_api.get_topology_id(name)
	local topo = cs2.get_topology_by_name(name)
	return topo and topo.id
end

---Set the associated surface indices for an existing topology.
---@param topology_id Id ID of the topology to modify.
---@param surface_indices int[] List of surface indices to associate with the topology.
---@return boolean success `true` if the topology was found and updated, `false` otherwise.
function cs2.remote_api.set_topology_surface_indices(
	topology_id,
	surface_indices
)
	local topology = cs2.get_topology(topology_id)
	if not topology then return false end
	topology:set_surface_indices(surface_indices)
	return true
end

---Get queues and capacities for a node.
---@param node_id Id ID of the node to query.
---@return uint? queue_size Size of the queue for the node. Includes all vehicles present or enroute, as well as additional vehicles that may be allowed by the queue_excess setting.
---@return uint? vehicle_capacity Total number of vehicles that can be enroute or at the node simultaneously.
---@return uint? total_deliveries Total number of deliveries for the node.
---@return uint? queue_excess Allowance by which the queue size may exceed the vehicle capacity.
---@return uint? delivery_excess Allowance by which the total deliveries may exceed the vehicle capacity.
function cs2.remote_api.get_node_vehicle_capacities(node_id)
	local node = cs2.get_node(node_id)
	if not node then return nil, nil, nil end
	local a, b, c = node:get_vehicle_capacities()
	local d = mod_settings.queue_limit
	local e = mod_settings.excess_delivery_limit
	return a, b, c, d, e
end
