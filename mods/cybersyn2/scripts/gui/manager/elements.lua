local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")
local fnlib = require("lib.core.function")
local tlib = require("lib.core.table")

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
		return HF({ vertical_align = "center" }, {
			ultros.BoldLabel({ "cybersyn2-manager.topology" }),
			ultros.Dropdown({
				value = props.topology_id,
				on_change = function(me, new_value) set_topology_id(new_value) end,
				options = options,
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

		return Pr(
			{
				type = "frame",
				style = "deep_frame_in_shallow_frame",
				direction = "horizontal",
				horizontally_stretchable = true,
				vertical_align = "center",
			},
			{
				ultros.Button({
					width = 30,
					caption = "<<",
					on_click = function(me, event)
						if page > 1 then set_page(1) end
					end,
				}),
				ultros.Button({
					width = 30,
					caption = "<",
					on_click = function(me, event)
						if page > 1 then set_page(page - 1) end
					end,
				}),
				ultros.Label(tostring(page) .. " / " .. tostring(n_pages)),
				ultros.Button({
					width = 30,
					caption = ">",
					on_click = function(me, event)
						if page < n_pages then set_page(page + 1) end
					end,
				}),
				ultros.Button({
					width = 30,
					caption = ">>",
					on_click = function(me, event)
						if page < n_pages then set_page(n_pages) end
					end,
				}),
			}
		)
	end
)

return lib
