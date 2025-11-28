--------------------------------------------------------------------------------
-- Route plugin interfaces
--------------------------------------------------------------------------------
local tlib = require("lib.core.table")
local stlib = require("lib.core.strace")
local signal = require("lib.signal")
local cs2 = _G.cs2

local route_plugins = prototypes.mod_data["cybersyn2"].data.route_plugins --[[@as {[string]: Cybersyn2.RoutePlugin} ]]

local reachable_callbacks = tlib.t_map_a(
	route_plugins or {},
	function(plugin) return plugin.reachable_callback end
) --[[@as Core.RemoteCallbackSpec[] ]]

---Invoke route plugin callbacks for determining reachability.
---@param vehicle_id Id ID of vehicle
---@param provider_id Id ID of providing node
---@param requester_id Id ID of requesting node
---@param train_stock LuaEntity? For trains, entity of the primary stock
---@param train_home_surface_index uint? For trains, index of the home surface
---@param from_stop_entity LuaEntity? For trains, entity of the from train-stop
---@param to_stop_entity LuaEntity? For trains, entity of the to train-stop
---@return boolean? veto_reachability If any plugin returns true, the route is vetoed.
function _G.cs2.query_reachable_callbacks(
	vehicle_id,
	provider_id,
	requester_id,
	train_stock,
	train_home_surface_index,
	from_stop_entity,
	to_stop_entity
)
	for _, callback in pairs(reachable_callbacks) do
		if callback then
			local result = remote.call(
				callback[1],
				callback[2],
				vehicle_id,
				provider_id,
				requester_id,
				train_stock,
				train_home_surface_index,
				from_stop_entity,
				to_stop_entity
			)
			if result then return true end
		end
	end
end
