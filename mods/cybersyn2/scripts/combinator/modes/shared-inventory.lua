--------------------------------------------------------------------------------
-- Shared inventory combinator
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local relm_helpers = require("__cybersyn2__.lib.relm-helpers")
local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local strace = stlib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local STATUS_SHARED_NONE = { color = "yellow", caption = "Nothing shared" }
local STATUS_SHARED_MASTER =
	{ color = "green", caption = "Sharing my inventory" }
local STATUS_SHARED_SLAVE =
	{ color = "green", caption = "Receiving shared inventory" }

---@param stop Cybersyn.TrainStop
local function get_status_props(stop)
	if stop.shared_inventory_master then
		return STATUS_SHARED_SLAVE
	elseif stop.shared_inventory_slaves then
		return STATUS_SHARED_MASTER
	else
		return STATUS_SHARED_NONE
	end
end

relm.define_element({
	name = "CombinatorGui.Mode.SharedInventory",
	render = function(props)
		relm_helpers.use_event("on_node_data_changed")
		local combinator = props.combinator:realize() --[[@as Cybersyn.Combinator]]
		local stop = cs2.get_stop(combinator and combinator.node_id or 0)
		if not stop then
			strace(
				stlib.WARN,
				"message",
				"Shared inventory combinator without associated train stop",
				combinator
			)
			return ultros.RtMultilineLabel("No associated train stop found.")
		end
		return ultros.WellSection(
			{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
			{
				gui.Status(get_status_props(stop)),
				ultros.If(
					stop:is_sharing_inventory(),
					ultros.Button({ caption = "Stop sharing inventory" })
				),
				ultros.If(
					not stop:is_sharing_inventory(),
					ultros.Button({ caption = "Start sharing inventory" })
				),
				ultros.If(
					stop:is_sharing_master(),
					ultros.Button({ caption = "Add shared inventory connection" })
				),
			}
		)
	end,
	message = function(me, payload)
		if payload.key == "on_node_data_changed" then
			relm.paint(me)
			return true
		end
		return false
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.SharedInventory.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-shared-inventory.desc",
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "shared-inventory",
	localized_string = "cybersyn2-combinator-modes.shared-inventory",
	settings_element = "CombinatorGui.Mode.SharedInventory",
	help_element = "CombinatorGui.Mode.SharedInventory.Help",
	is_output = true,
})
