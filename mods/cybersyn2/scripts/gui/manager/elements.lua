local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local fnlib = require("lib.core.function")
local tlib = require("lib.core.table")

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow
local noop = fnlib.noop

local lib = {}

lib.TopologySelector = relm.define(
	"Manager.TopologySelector",
	---@param props { topology_id: integer?, set_topology_id: fun(id: integer?) }
	function(props)
		local set_topology_id = props.set_topology_id or noop
		local options = tlib.t_map_a(
			storage.topologies,
			function(topo)
				return { caption = topo.name or ("Topology " .. topo.id), key = topo.id }
			end
		)
		return HF({ vertically_stretchable = true, vertical_align = "center" }, {
			ultros.BoldLabel({ "cybersyn2-manager.topology" }),
			ultros.Dropdown({
				value = props.topology_id,
				on_change = function(me, new_value) set_topology_id(new_value) end,
				options = options,
			}),
		})
	end
)

lib.CargoSelector = relm.define(
	"Manager.CargoSelector",
	---@param props { cargo: SignalID?, set_cargo: fun(cargo: SignalID?) }
	function(props)
		local set_cargo = props.set_cargo or noop
		return HF({ vertically_stretchable = true, vertical_align = "center" }, {
			ultros.BoldLabel({ "cybersyn2-manager.cargo" }),
			ultros.ChooseElemButton({
				value = props.cargo,
				on_change = function(me, new_value) set_cargo(new_value) end,
			}),
		})
	end
)

lib.NetworkSelector = relm.define(
	"Manager.NetworkSelector",
	---@param props { network: string?, set_network: fun(network: string?) }
	function(props)
		local set_network = props.set_network or noop
		return HF({ vertically_stretchable = true, vertical_align = "center" }, {
			ultros.BoldLabel({ "cybersyn2-manager.network" }),
			ultros.ChooseElemButton({
				virtual_signal = props.network,
				on_change = function(me, new_value)
					if new_value and new_value.type == "virtual" then
						set_network(new_value.name)
					else
						set_network(nil)
					end
				end,
			}),
		})
	end
)

lib.Pager = relm.define(
	"Manager.Pager",
	---@param props { page: integer, set_page: fun(page: integer), n_pages: integer }
	function(props)
		local page = props.page
		local set_page = props.set_page or noop
		local n_pages = props.n_pages or 1

		return Pr({
			type = "frame",
			style = "deep_frame_in_shallow_frame",
			direction = "horizontal",
			horizontally_stretchable = true,
			vertical_align = "center",
			top_padding = 4,
			bottom_padding = 4,
		}, {
			ultros.Button({
				width = 35,
				caption = "<<",
				on_click = function(me, event)
					if page > 1 then set_page(1) end
				end,
			}),
			ultros.Button({
				width = 35,
				caption = "<",
				on_click = function(me, event)
					if page > 1 then set_page(page - 1) end
				end,
			}),
			ultros.Label({ "", "Page ", page, " of ", n_pages }),
			ultros.Button({
				width = 35,
				caption = ">",
				on_click = function(me, event)
					if page < n_pages then set_page(page + 1) end
				end,
			}),
			ultros.Button({
				width = 35,
				caption = ">>",
				on_click = function(me, event)
					if page < n_pages then set_page(n_pages) end
				end,
			}),
		})
	end
)

return lib
