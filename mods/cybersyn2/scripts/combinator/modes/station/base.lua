--------------------------------------------------------------------------------
-- Station combinator.
--------------------------------------------------------------------------------

local relm = require("__cybersyn2__.lib.relm")
local ultros = require("__cybersyn2__.lib.ultros")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local combinator_settings = _G.cs2.combinator_settings

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

--------------------------------------------------------------------------------
-- Station combinator settings.
--------------------------------------------------------------------------------

-- Name of the network virtual signal.
combinator_api.register_setting(
	combinator_api.make_raw_setting("network_signal", "network")
)
-- Whether the station should provide, request, or both. Encoded as an integer 0, 1, or 2.
combinator_api.register_setting(combinator_api.make_raw_setting("pr", "pr"))

combinator_api.register_setting(
	combinator_api.make_flag_setting("use_stack_thresholds", "station_flags", 0)
)

--------------------------------------------------------------------------------
-- Station combinator GUI.
--------------------------------------------------------------------------------

---@param event EventData.on_gui_elem_changed
---@param settings Cybersyn.Combinator.Ephemeral
local function handle_network(event, settings)
	local signal = event.element.elem_value
	local stored = nil
	if
		signal
		and signal.type == "virtual"
		and not cs2.CONFIGURATION_VIRTUAL_SIGNAL_SET[signal.name]
	then
		stored = signal.name
		if
			signal.name == "signal-everything"
			or signal.name == "signal-anything"
			or signal.name == "signal-each"
		then
			stored = "signal-each"
		end
	end
	combinator_api.write_setting(
		settings,
		combinator_settings.network_signal,
		stored
	)
end

---@param event EventData.on_gui_switch_state_changed
---@param settings Cybersyn.Combinator.Ephemeral
local function handle_pr_switch(event, settings)
	local element = event.element
	local is_pr_state = (element.switch_state == "none" and 0)
		or (element.switch_state == "left" and 1)
		or 2
	combinator_api.write_setting(settings, combinator_settings.pr, is_pr_state)
end

---@param parent LuaGuiElement
local function create_gui(parent)
	flib_gui.add(parent, {
		{
			type = "label",
			style = "heading_2_label",
			caption = { "cybersyn2-gui.settings" },
			style_mods = { top_padding = 8 },
		},
		{
			type = "switch",
			name = "is_pr_switch",
			allow_none_state = true,
			switch_state = "none",
			handler = handle_pr_switch,
			left_label_caption = { "cybersyn2-gui.switch-provide" },
			right_label_caption = { "cybersyn2-gui.switch-request" },
			left_label_tooltip = { "cybersyn2-gui.switch-provide-tooltip" },
			right_label_tooltip = { "cybersyn2-gui.switch-request-tooltip" },
		},
		{
			type = "flow",
			name = "network_flow",
			direction = "horizontal",
			style_mods = {
				vertical_align = "center",
				horizontally_stretchable = true,
			},
			children = {
				{
					type = "label",
					caption = { "cybersyn2-gui.network" },
				},
				{
					type = "flow",
					style_mods = { horizontally_stretchable = true },
				},
				{
					type = "choose-elem-button",
					name = "network_button",
					handler = handle_network,
					style = "slot_button_in_shallow_frame",
					tooltip = { "cybersyn2-gui.network-tooltip" },
					elem_type = "signal",
				},
			},
		},
		{
			type = "checkbox",
			name = "is_stack",
			state = false,
			handler = combinator_api.generic_checkbox_handler,
			tags = { setting = "use_stack_thresholds" },
			tooltip = { "cybersyn2-gui.is-stack-tooltip" },
			caption = { "cybersyn2-gui.is-stack-description" },
		},
		-- {
		-- 	type = "flow",
		-- 	name = "circuit_go_flow",
		-- 	direction = "horizontal",
		-- 	style_mods = { vertical_align = "center", horizontally_stretchable = true },
		-- 	children = {
		-- 		{
		-- 			type = "label",
		-- 			caption = "Circuit condition: allow departure",
		-- 		},
		-- 		{
		-- 			type = "flow",
		-- 			style_mods = { horizontally_stretchable = true },
		-- 		},
		-- 		{
		-- 			type = "choose-elem-button",
		-- 			name = "circuit_go_button",
		-- 			style = "slot_button_in_shallow_frame",
		-- 			style_mods = { right_margin = 8 },
		-- 			tooltip = { "cybersyn-gui.network-tooltip" },
		-- 			elem_type = "signal",
		-- 		},
		-- 	},
		-- },
	})
end

---@param parent LuaGuiElement
---@param settings Cybersyn.Combinator.Ephemeral
local function update_gui(parent, settings, _)
	local switch_state = "none"
	local is_pr_state
	combinator_api.read_setting(settings, combinator_settings.pr)
	if is_pr_state == 0 then
		switch_state = "none"
	elseif is_pr_state == 1 then
		switch_state = "left"
	elseif is_pr_state == 2 then
		switch_state = "right"
	end
	parent["is_pr_switch"].switch_state = switch_state

	local network_signal_name =
		combinator_api.read_setting(settings, combinator_settings.network_signal)
	local network_signal = nil
	if network_signal_name then
		network_signal = { name = network_signal_name, type = "virtual" }
	end
	parent["network_flow"]["network_button"].elem_value = network_signal

	parent["is_stack"].state = combinator_api.read_setting(
		settings,
		combinator_settings.use_stack_thresholds
	)
end

-- TODO: factor out
local SignalPicker = ultros.SignalPicker

relm.define_element({
	name = "CombinatorGui.Mode.Station",
	render = function(props)
		return VF({
			Pr({ type = "line", direction = "horizontal" }),
			ultros.Labeled({ caption = "Cargo", top_margin = 6 }, {
				Pr({
					type = "switch",
					allow_none_state = true,
					switch_state = "none",
					left_label_caption = "Outbound only",
					right_label_caption = "Inbound only",
				}),
			}),
			ultros.Labeled(
				{ caption = { "cybersyn2-gui.network" }, top_margin = 6 },
				{
					SignalPicker({
						virtual_signal = combinator_api.read_setting(
							props.combinator,
							combinator_settings.network_signal
						),
						on_change = function(_, signal, elem)
							if
								signal.type == "virtual"
								and not cs2.CONFIGURATION_VIRTUAL_SIGNAL_SET[signal.name]
							then
								local stored = signal.name
								if
									signal.name == "signal-everything"
									or signal.name == "signal-anything"
									or signal.name == "signal-each"
								then
									stored = "signal-each"
								end

								combinator_api.write_setting(
									props.combinator,
									combinator_settings.network_signal,
									stored
								)
							else
								game.print(
									"Invalid signal type. Please select a non-configuration virtual signal.",
									{
										color = { 255, 128, 0 },
										skip = defines.print_skip.never,
										sound = defines.print_sound.always,
									}
								)
								elem.elem_value = nil
							end
						end,
					}),
				}
			),
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				top_margin = 6,
				font = "default-bold",
				caption = "Flags",
			}),
			Pr({
				type = "checkbox",
				state = false,
				tooltip = { "cybersyn2-gui.is-stack-tooltip" },
				caption = { "cybersyn2-gui.is-stack-description" },
			}),
			ultros.Fold({ caption = "Advanced", top_margin = 12 }, {
				ultros.Labeled(
					{ caption = "Signal: Allow departure", top_margin = 6 },
					{
						SignalPicker(),
					}
				),
				ultros.Labeled(
					{ caption = "Signal: Force departure", top_margin = 6 },
					{
						SignalPicker(),
					}
				),
				ultros.Labeled({ caption = "Inactivity mode", top_margin = 6 }, {
					Pr({
						type = "switch",
						allow_none_state = true,
						switch_state = "left",
						left_label_caption = "After delivery",
						right_label_caption = "Force out",
					}),
				}),
				ultros.Labeled(
					{ caption = "Inactivity timeout (sec)", top_margin = 6 },
					{
						Pr({
							type = "textfield",
							text = "5",
							width = 75,
							numeric = true,
							allow_decimal = false,
							allow_negative = false,
						}),
					}
				),
				Pr({
					type = "label",
					font_color = { 255, 230, 192 },
					top_margin = 6,
					font = "default-bold",
					caption = "Flags",
				}),
				Pr({
					type = "checkbox",
					state = true,
					caption = "Use cargo condition",
				}),
			}),
		})
	end,
	message = function(me, payload, props, state)
		if payload.key == "toggle_advanced" then
			local advanced = state and not state.advanced
			relm.set_state(me, function()
				return { advanced = advanced }
			end)
			return true
		end
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.Station.Help",
	render = function(props)
		return VF({
			Pr({
				type = "label",
				font_color = { 255, 230, 192 },
				font = "default-bold",
				caption = "Signal Inputs",
			}),
			Pr({ type = "line", direction = "horizontal" }),
			Pr({
				type = "table",
				column_count = 2,
				draw_horizontal_line_after_headers = true,
			}, {
				Pr({
					type = "label",
					font = "default-bold",
					caption = "Signal",
				}),
				Pr({
					type = "label",
					font = "default-bold",
					caption = "Effect",
				}),
				Pr({
					type = "label",
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "[item=iron-ore][item=copper-plate]...",
				}),
				Pr({
					type = "label",
					single_line = false,
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "Set station inventory. Positive values indicate available cargo, while negative values indicate requested cargo.",
				}),
				Pr({
					type = "label",
					font = "default-large",
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "[virtual-signal=cybersyn2-priority]",
				}),
				Pr({
					type = "label",
					single_line = false,
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "Set the priority for all items at this station.",
				}),
				Pr({
					type = "label",
					font = "default-large",
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "[virtual-signal=cybersyn2-all-items]",
				}),
				Pr({
					type = "label",
					single_line = false,
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "Set the inbound delivery threshold for all items at this station.",
				}),
				Pr({
					type = "label",
					font = "default-large",
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "[virtual-signal=cybersyn2-all-fluids]",
				}),
				Pr({
					type = "label",
					single_line = false,
					rich_text_setting = defines.rich_text_setting.enabled,
					caption = "Set the inbound delivery threshold for all fluids at this station.",
				}),
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Station combinator mode registration.
--------------------------------------------------------------------------------

combinator_api.register_combinator_mode({
	name = "station",
	localized_string = "cybersyn2-gui.station",
	settings_element = "CombinatorGui.Mode.Station",
	help_element = "CombinatorGui.Mode.Station.Help",
})
