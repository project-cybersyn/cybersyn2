local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local stlib = require("lib.core.strace")
local events = require("lib.core.event")
local cs2 = _G.cs2

local strace = stlib.strace
local empty = tlib.empty
local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "wagon_contents",
	localized_string = "cybersyn2-combinator-modes.wagon-contents",
	settings_element = "CombinatorGui.Mode.WagonContents",
	help_element = "CombinatorGui.Mode.WagonContents.Help",
	is_output = true,
})

--------------------------------------------------------------------------------
-- Proxy chest management
--------------------------------------------------------------------------------

local O_RED = defines.wire_connector_id.combinator_output_red
local O_GREEN = defines.wire_connector_id.combinator_output_green
local O_CHEST_RED = defines.wire_connector_id.circuit_red
local O_CHEST_GREEN = defines.wire_connector_id.circuit_green
local SCRIPT = defines.wire_origin.script

---@param combinator Cybersyn.Combinator
---@param force_destroy boolean?
local function create_or_destroy_hidden_chest(combinator, force_destroy)
	local _, chest =
		remote.call("things", "get_transient_child", combinator.id, "proxy_chest")
	if
		combinator.mode == "wagon_contents"
		and combinator.real_entity
		and not force_destroy
	then
		-- Create chest if it doesn't exist
		if chest and chest.valid then return end

		local combinator_entity = combinator.real_entity --[[@as LuaEntity]]

		chest = combinator_entity.surface.create_entity({
			name = "cybersyn2-proxy-chest",
			position = combinator_entity.position,
			force = combinator_entity.force,
		})

		if not chest then
			stlib.error(
				"Combinator",
				combinator.id,
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

		stlib.debug(
			"Combinator",
			combinator.id,
			"Created hidden proxy chest entity"
		)
		remote.call(
			"things",
			"add_transient_child",
			combinator.id,
			"proxy_chest",
			chest
		)
	elseif chest then
		stlib.debug(
			"Combinator",
			combinator.id,
			"Destroying hidden proxy chest entity"
		)
		remote.call(
			"things",
			"remove_transient_child",
			combinator.id,
			"proxy_chest",
			true
		)
	end
end

---@param comb Cybersyn.Combinator
local function clear_combinator(comb)
	comb:direct_write_outputs(empty)
	local _, chest =
		remote.call("things", "get_transient_child", comb.id, "proxy_chest")
	if chest and chest.valid then
		chest.proxy_target_entity = nil
		stlib.debug("Combinator", comb.id, "Cleared proxy target entity")
	end
end

---@param comb Cybersyn.Combinator
---@param wagon LuaEntity
local function set_proxy_chest_inventory(comb, wagon)
	local _, chest =
		remote.call("things", "get_transient_child", comb.id, "proxy_chest")
	if chest and chest.valid then
		if wagon and wagon.type == "cargo-wagon" then
			chest.proxy_target_entity = wagon
			chest.proxy_target_inventory = defines.inventory.cargo_wagon
			stlib.debug(
				"Combinator",
				comb.id,
				"Set proxy target entity to wagon",
				wagon
			)
		else
			chest.proxy_target_entity = nil
			stlib.debug(
				"Combinator",
				comb.id,
				"Cleared proxy target entity (no wagon)"
			)
		end
	end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

events.bind(
	"cs2.combinator_status_changed",
	function(comb) create_or_destroy_hidden_chest(comb) end
)

events.bind("cs2.combinator_node_associated", function(comb, new, prev)
	if comb.mode == "wagon_contents" then clear_combinator(comb) end
end)

events.bind(
	"cs2.combinator_settings_changed",
	function(combinator, key, new_value, old_value)
		if
			key == nil
			or (
				key == "mode"
				and (new_value == "wagon_contents" or old_value == "wagon_contents")
			)
		then
			create_or_destroy_hidden_chest(combinator)
		end
	end
)

-- On train departure, clear all wagon combs.
cs2.on_train_departed(function(train, cstrain, stop)
	if not cstrain or not stop then return end
	for _, comb in cs2.iterate_combinators(stop) do
		if comb.mode == "wagon_contents" then clear_combinator(comb) end
	end
end)

cs2.on_train_arrived(function(train, cstrain, stop)
	if not cstrain or not stop then return end
	for _, comb in cs2.iterate_combinators(stop) do
		if comb.mode == "wagon_contents" then
			local wagon = comb:find_connected_wagon()
			if wagon then
				set_proxy_chest_inventory(comb, wagon)
			else
				clear_combinator(comb)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define("CombinatorGui.Mode.WagonContents", function(props) return nil end)

relm.define(
	"CombinatorGui.Mode.WagonContents.Help",
	function(props)
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
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.signal" }),
				ultros.BoldLabel({ "cybersyn2-combinator-modes-labels.value" }),
				ultros.RtLabel("[item=iron-ore][item=copper-plate]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-wagon-contents.output-signals",
				}),
			}),
		})
	end
)
