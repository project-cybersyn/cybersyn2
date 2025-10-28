--------------------------------------------------------------------------------
-- Deliveries output combinator
--------------------------------------------------------------------------------

local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local signal_lib = require("lib.signal")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local Delivery = _G.cs2.Delivery
local signal_to_key = signal_lib.signal_to_key
local key_to_signal = signal_lib.key_to_signal
local Pr = relm.Primitive
local VF = ultros.VFlow

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

-- Exclude inbounds from deliveries output
cs2.register_combinator_setting(
	cs2.lib.make_flag_setting("deliveries_exclude_inbound", "deliveries_flags", 0)
)

-- Exclude outbounds from deliveries output
cs2.register_combinator_setting(
	cs2.lib.make_flag_setting(
		"deliveries_exclude_outbound",
		"deliveries_flags",
		1
	)
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Deliveries",
	render = function(props)
		return VF({
			ultros.WellSection(
				{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
				{
					gui.InnerHeading({
						caption = "Flags",
					}),
					gui.Checkbox(
						{ "cybersyn2-combinator-mode-deliveries.include-inbound" },
						{ "cybersyn2-combinator-mode-deliveries.include-inbound-tooltip" },
						props.combinator,
						combinator_settings.deliveries_exclude_inbound,
						true
					),
					gui.Checkbox(
						{ "cybersyn2-combinator-mode-deliveries.include-outbound" },
						{ "cybersyn2-combinator-mode-deliveries.include-outbound-tooltip" },
						props.combinator,
						combinator_settings.deliveries_exclude_outbound,
						true
					),
				}
			),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Deliveries.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-deliveries.desc" }),
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
				ultros.RtLabel("[item=iron-ore][item=copper-plate][fluid=water]..."),
				ultros.RtMultilineLabel({
					"cybersyn2-combinator-mode-deliveries.output-signals",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "deliveries",
	localized_string = "cybersyn2-combinator-modes.deliveries",
	settings_element = "CombinatorGui.Mode.Deliveries",
	help_element = "CombinatorGui.Mode.Deliveries.Help",
	is_output = true,
	is_input = false,
})

--------------------------------------------------------------------------------
-- Impl
--------------------------------------------------------------------------------

---@param node Cybersyn.Node
---@param comb Cybersyn.Combinator
local function update_delivery_combinator(node, comb)
	local deliveries = node:get_deliveries()
	if not deliveries then return end
	local exclude_inbound =
		comb:read_setting(combinator_settings.deliveries_exclude_inbound)
	local exclude_outbound =
		comb:read_setting(combinator_settings.deliveries_exclude_outbound)

	---@type SignalCounts
	local signals = {}
	for delivery_id in pairs(deliveries) do
		local delivery = cs2.get_delivery(delivery_id, true)
		if delivery and delivery.from_id == node.id and not exclude_outbound then
			tlib.vector_add(signals, -1, delivery.manifest)
		elseif delivery and delivery.to_id == node.id and not exclude_inbound then
			tlib.vector_add(signals, 1, delivery.manifest)
		end
	end

	comb:write_outputs(signals, 1)
end

---@param node Cybersyn.Node
local function update_delivery_combinators(node)
	local combs = node:get_associated_combinators(
		function(comb) return comb.mode == "deliveries" end
	)
	if #combs == 0 then return end
	for _, comb in pairs(combs) do
		update_delivery_combinator(node, comb)
	end
end

cs2.on_node_deliveries_changed(
	function(node) update_delivery_combinators(node) end
)

cs2.on_combinator_node_associated(function(comb, node)
	if node and comb.mode == "deliveries" then
		update_delivery_combinator(node, comb)
	end
end)

cs2.on_combinator_setting_changed(function(comb, setting)
	if
		setting == nil
		or setting == "mode"
		or setting == "deliveries_exclude_inbound"
		or setting == "deliveries_exclude_outbound"
	then
		if comb.mode == "deliveries" then
			-- Update the combinator if it is in deliveries mode.
			local node = comb:get_node()
			if node then update_delivery_combinator(node, comb) end
		end
	end
end)
