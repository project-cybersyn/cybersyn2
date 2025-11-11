local strace = require("lib.core.strace")
local cs2 = _G.cs2

---@type table<string, fun(query: Cybersyn.QueryInput): Cybersyn.QueryResult>
_G.cs2.query_handlers = {}

-- Things tag migration callback
function _G.cs2.remote_api.migrate_tags_callback(tags) return tags end

-- Things initial tags callback
function _G.cs2.remote_api.initial_tags_callback(entity)
	return cs2.DEFAULT_COMBINATOR_SETTINGS
end

---Invoked by a route plugin to hand control of a train back to Cybersyn 2
---when the plugin is done routing it. May also optionally replace the
---LuaTrain ID that Cybersyn 2 uses to track the train.
---@param delivery_id uint ID of the delivery being handed back.
---@param new_luatrain? LuaTrain A new LuaTrain object to replace the existing one.
function _G.cs2.remote_api.route_plugin_handoff(delivery_id, new_luatrain)
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

---Force Cybersyn 2 to rebuild all train topologies. This should be called by
---routing plugins when the network of surfaces reachable from each other
---changes.
function _G.cs2.remote_api.rebuild_train_topologies()
	cs2.rebuild_train_topologies()
end
