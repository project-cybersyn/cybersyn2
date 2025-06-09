--------------------------------------------------------------------------------
-- Manifest output combinator
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local signal_lib = require("__cybersyn2__.lib.signal")
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

-- Virtual signal supplied when a train is dropping off
cs2.register_combinator_setting(
	cs2.lib.make_raw_setting("dropoff_signal", "dropoff_signal")
)

-- Virtual signal supplied when a train is picking up
cs2.register_combinator_setting(
	cs2.lib.make_raw_setting("pickup_signal", "pickup_signal")
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

relm.define_element({
	name = "CombinatorGui.Mode.Manifest",
	render = function(props)
		return VF({
			ultros.WellSection(
				{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
				{
					ultros.Labeled({
						caption = { "cybersyn2-combinator-mode-manifest.signal-dropoff" },
						top_margin = 6,
					}, {
						gui.VirtualSignalPicker(
							props.combinator,
							combinator_settings.dropoff_signal,
							{
								"cybersyn2-combinator-mode-manifest.tooltip-dropoff",
							}
						),
					}),
					ultros.Labeled({
						caption = { "cybersyn2-combinator-mode-manifest.signal-pickup" },
						top_margin = 6,
					}, {
						gui.VirtualSignalPicker(
							props.combinator,
							combinator_settings.pickup_signal,
							{ "cybersyn2-combinator-mode-manifest.tooltip-pickup" }
						),
					}),
				}
			),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Manifest.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-manifest.desc" }),
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
					"cybersyn2-combinator-mode-manifest.output-signals",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "manifest",
	localized_string = "cybersyn2-combinator-modes.manifest",
	settings_element = "CombinatorGui.Mode.Manifest",
	help_element = "CombinatorGui.Mode.Manifest.Help",
	is_output = true,
})

--------------------------------------------------------------------------------
-- Impl
--------------------------------------------------------------------------------

cs2.on_train_arrived(function(train, cstrain, stop)
	-- Validate relevance of delivery
	if not cstrain or not stop or not cstrain.delivery_id then return end
	local delivery = Delivery.get(cstrain.delivery_id) --[[@as Cybersyn.TrainDelivery?]]
	if not delivery then return end
	if delivery.from_id ~= stop.id and delivery.to_id ~= stop.id then return end

	-- Get train combs.
	local combs = stop:get_associated_combinators(
		function(c) return c.mode == "manifest" end
	)
	if not combs or #combs == 0 then return end

	if delivery.from_id == stop.id then
		-- Pickup
		for _, comb in pairs(combs) do
			local pickup_signal = comb:read_setting(combinator_settings.pickup_signal)
			if pickup_signal then
				comb:write_outputs(
					delivery.manifest,
					-1,
					{ [pickup_signal.name] = 1 },
					1
				)
			else
				comb:write_outputs(delivery.manifest, -1)
			end
		end
	elseif delivery.to_id == stop.id then
		-- Dropoff
		for _, comb in pairs(combs) do
			local dropoff_signal =
				comb:read_setting(combinator_settings.dropoff_signal)
			if dropoff_signal then
				comb:write_outputs(
					delivery.manifest,
					1,
					{ [dropoff_signal.name] = 1 },
					1
				)
			else
				comb:write_outputs(delivery.manifest, 1)
			end
		end
	end
end)

cs2.on_train_departed(function(train, cstrain, stop)
	if not cstrain or not stop then return end
	-- On train departure, clear all manifest combs.
	local combs = stop:get_associated_combinators(
		function(c) return c.mode == "manifest" end
	)
	if #combs > 0 then
		local empty = {}
		for _, comb in pairs(combs) do
			comb:direct_write_outputs(empty)
		end
	end
end)
