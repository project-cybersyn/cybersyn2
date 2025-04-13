--------------------------------------------------------------------------------
-- Wagon contents output combinator
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local signal_lib = require("__cybersyn2__.lib.signal")
local stlib = require("__cybersyn2__.lib.strace")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local strace = stlib.strace
local ERROR = stlib.ERROR
local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.WagonContents",
	render = function(props) return nil end,
})

relm.define_element({
	name = "CombinatorGui.Mode.WagonContents.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-wagon-contents.desc",
			}),
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = { "cybersyn2-combinator-modes-labels.signal-outputs" },
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
			}, {
				ultros.BoldLabel("Signal"),
				ultros.BoldLabel("Value"),
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-wagon-contents.output-signals",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "wagon-contents",
	localized_string = "cybersyn2-combinator-modes.wagon-contents",
	settings_element = "CombinatorGui.Mode.WagonContents",
	help_element = "CombinatorGui.Mode.WagonContents.Help",
	is_output = true,
})

--------------------------------------------------------------------------------
-- Hidden chest
--------------------------------------------------------------------------------

local O_RED = defines.wire_connector_id.combinator_output_red
local O_GREEN = defines.wire_connector_id.combinator_output_green
local O_CHEST_RED = defines.wire_connector_id.circuit_red
local O_CHEST_GREEN = defines.wire_connector_id.circuit_green
local SCRIPT = defines.wire_origin.script

---@param combinator Cybersyn.Combinator
---@param force_destroy boolean?
local function create_or_destroy_hidden_chest(combinator, force_destroy)
	if combinator.mode == "wagon-contents" and not force_destroy then
		if (not combinator.proxy_chest) or not combinator.proxy_chest.valid then
			local combinator_entity = combinator.entity --[[@as LuaEntity]]

			local chest = combinator_entity.surface.create_entity({
				name = "cybersyn2-proxy-chest",
				position = combinator.entity.position,
				force = combinator.entity.force,
			})

			if not chest then
				strace(
					ERROR,
					"cs2",
					"combinator",
					"message",
					"Failed to create hidden proxy chest entity"
				)
				return
			end

			-- Wire chest to combinator outputs
			local comb_red = combinator_entity.get_wire_connector(O_RED, true)
			local comb_green = combinator_entity.get_wire_connector(O_GREEN, true)
			local chest_red = chest.get_wire_connector(O_CHEST_RED, true)
			local chest_green = chest.get_wire_connector(O_CHEST_GREEN, true)
			chest_red.connect_to(comb_red, false, SCRIPT)
			chest_green.connect_to(comb_green, false, SCRIPT)

			strace(
				stlib.DEBUG,
				"cs2",
				"combinator",
				"message",
				"Created hidden proxy chest entity"
			)

			combinator.proxy_chest = chest
		end
	else
		if combinator.proxy_chest then
			if combinator.proxy_chest.valid then combinator.proxy_chest.destroy() end
			combinator.proxy_chest = nil
			strace(
				stlib.DEBUG,
				"cs2",
				"combinator",
				"message",
				"Destroyed hidden proxy chest entity"
			)
		end
	end
end

cs2.on_combinator_created(create_or_destroy_hidden_chest)
cs2.on_combinator_setting_changed(function(combinator, setting)
	if setting == "mode" or setting == nil then
		create_or_destroy_hidden_chest(combinator)
	end
end)
cs2.on_combinator_destroyed(
	function(combinator) create_or_destroy_hidden_chest(combinator, true) end
)

--------------------------------------------------------------------------------
-- Impl
--------------------------------------------------------------------------------

cs2.on_train_arrived(function(train, cstrain, stop)
	if not cstrain or not stop then return end
	local combs = stop:get_associated_combinators(
		function(combinator) return combinator.mode == "wagon-contents" end
	)
	for _, comb in pairs(combs) do
		if comb.proxy_chest and comb.proxy_chest.valid then
			local wagon = comb:find_connected_wagon()
			if wagon and wagon.type == "cargo-wagon" then
				comb.proxy_chest.proxy_target_entity = wagon
				comb.proxy_chest.proxy_target_inventory = defines.inventory.cargo_wagon
				strace(
					stlib.DEBUG,
					"cs2",
					"combinator",
					"message",
					"Set proxy target to wagon",
					wagon
				)
			else
				comb.proxy_chest.proxy_target_entity = nil
				strace(
					stlib.DEBUG,
					"cs2",
					"combinator",
					"message",
					"Cleared proxy target entity"
				)
			end
		end
	end
end)

cs2.on_train_departed(function(train, cstrain, stop)
	if not cstrain or not stop then return end
	local combs = stop:get_associated_combinators(
		function(combinator) return combinator.mode == "wagon-contents" end
	)
	for _, comb in pairs(combs) do
		if comb.proxy_chest and comb.proxy_chest.valid then
			comb.proxy_chest.proxy_target_entity = nil
			strace(
				stlib.DEBUG,
				"cs2",
				"combinator",
				"message",
				"Cleared proxy target entity"
			)
		end
	end
end)
