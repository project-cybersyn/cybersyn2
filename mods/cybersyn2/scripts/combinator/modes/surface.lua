--------------------------------------------------------------------------------
-- Surface inventory output combinator
--------------------------------------------------------------------------------

local tlib = require("lib.core.table")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local signal_lib = require("lib.signal")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local Topology = _G.cs2.Topology
local Delivery = _G.cs2.Delivery
local signal_to_key = signal_lib.signal_to_key
local key_to_signal = signal_lib.key_to_signal
local Pr = relm.Primitive
local VF = ultros.VFlow
local empty = tlib.empty

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

-- Which inventory data to include in the combinator output.
cs2.register_combinator_setting(
	cs2.lib.make_raw_setting(
		"surface_inventory_mode",
		"surface_inventory_mode",
		"provided"
	)
)

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local mode_dropdown_items = {
	{
		key = "provided",
		caption = { "cybersyn2-combinator-mode-surface.provided" },
	},
	{ key = "pulled", caption = { "cybersyn2-combinator-mode-surface.pulled" } },
	{ key = "pushed", caption = { "cybersyn2-combinator-mode-surface.pushed" } },
	{ key = "sunk", caption = { "cybersyn2-combinator-mode-surface.sunk" } },
}

relm.define_element({
	name = "CombinatorGui.Mode.Surface",
	render = function(props)
		return VF({
			ultros.WellSection(
				{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
				{
					ultros.Labeled({
						caption = { "cybersyn2-combinator-mode-surface.output-mode" },
						top_margin = 6,
					}, {
						gui.Dropdown(
							nil,
							props.combinator,
							combinator_settings.surface_inventory_mode,
							mode_dropdown_items
						),
					}),
				}
			),
		})
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Surface.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({ "cybersyn2-combinator-mode-surface.desc" }),
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
					"cybersyn2-combinator-mode-surface.output-signals",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

cs2.register_combinator_mode({
	name = "surface",
	localized_string = "cybersyn2-combinator-modes.surface",
	settings_element = "CombinatorGui.Mode.Surface",
	help_element = "CombinatorGui.Mode.Surface.Help",
	is_output = true,
	is_input = false,
})

--------------------------------------------------------------------------------
-- Impl
--------------------------------------------------------------------------------

---@param top Cybersyn.Topology
local function update_surface_combinators(top)
	if not top.global_combinators then return end
	local combs = tlib.t_map_a(
		top.global_combinators,
		function(_, id) return cs2.get_combinator(id) end
	)
	local provided, pulled, pushed, sunk
	for _, comb in pairs(combs) do
		if comb.mode == "surface" then
			local submode =
				comb:read_setting(combinator_settings.surface_inventory_mode)
			local outputs = nil
			if submode == "provided" then
				if not provided then
					provided = comb:encode_outputs(top.provided or empty, 1)
				end
				outputs = provided
			elseif submode == "pulled" then
				if not pulled then
					pulled = comb:encode_outputs(top.pulled or empty, 1)
				end
				outputs = pulled
			elseif submode == "pushed" then
				if not pushed then
					pushed = comb:encode_outputs(top.pushed or empty, 1)
				end
				outputs = pushed
			elseif submode == "sunk" then
				if not sunk then sunk = comb:encode_outputs(top.sunk or empty, 1) end
				outputs = sunk
			end
			comb:direct_write_outputs(outputs or {})
		end
	end
end

cs2.on_topology_inventory_updated(
	function(top) update_surface_combinators(top) end
)

cs2.on_combinator_setting_changed(function(comb, setting)
	if setting == nil or setting == "mode" then
		-- TODO: better topology determination
		local top = Topology.get_train_topology(comb.entity.surface_index)
		if not top then return end
		if comb.mode == "surface" then
			top:add_global_combinator(comb)
		else
			top:remove_global_combinator(comb)
		end
	end
end)

cs2.on_combinator_created(function(comb)
	if comb.mode == "surface" then
		-- TODO: better topology determination
		local top = Topology.get_train_topology(comb.entity.surface_index)
		if not top then return end
		top:add_global_combinator(comb)
	end
end)

cs2.on_combinator_destroyed(function(comb)
	if comb.mode == "surface" then
		-- TODO: better topology determination
		local top = Topology.get_train_topology(comb.entity.surface_index)
		if not top then return end
		top:remove_global_combinator(comb)
	end
end)

-- When a top is created, enum all combinators that might be global
cs2.on_topologies(function(top, event)
	if event == "created" then
		local comb_ents = top:get_combinator_entities()
		local combs = tlib.map(
			comb_ents,
			function(ent) return cs2.get_combinator(ent.unit_number) end
		)
		for _, comb in pairs(combs) do
			if comb.mode == "surface" then top:add_global_combinator(comb) end
		end
	end
end)
