local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local mgr_elts = require("scripts.gui.manager.elements")

local Pr = relm.Primitive

local lib = {}

lib.DeliveriesTab = relm.define(
	"Manager.DeliveriesTab",
	---@param props {active_topology_id: integer?, set_active_topology_id: fun(id: integer?), cargo: SignalID?, set_cargo: fun(cargo: SignalID?), network: string?, set_network: fun(network: string?)}
	function(props)
		local cargo, set_cargo = props.cargo, props.set_cargo
		local network, set_network = props.network, props.set_network

		return {
			Pr({
				type = "frame",
				style = "inside_shallow_frame_with_padding",
				horizontally_stretchable = true,
				vertically_stretchable = false,
				top_padding = 2,
				bottom_padding = 2,
				vertical_align = "center",
			}, {
				mgr_elts.TopologySelector({
					topology_id = props.active_topology_id,
					set_topology_id = props.set_active_topology_id,
				}),
				mgr_elts.CargoSelector({ cargo = cargo, set_cargo = set_cargo }),
				mgr_elts.NetworkSelector({
					network = network,
					set_network = set_network,
				}),
			}),
		}
	end
)

return lib
