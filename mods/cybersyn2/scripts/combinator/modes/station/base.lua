--------------------------------------------------------------------------------
-- Station combinator.
--------------------------------------------------------------------------------

-- flib_gui typing causes a lot of extraneous missing fields errors
---@diagnostic disable: missing-fields

local flib_gui = require("__flib__.gui")

--------------------------------------------------------------------------------
-- Station combinator settings.
--------------------------------------------------------------------------------

-- Name of the network virtual signal.
combinator_api.register_setting(combinator_api.make_raw_setting("network_signal", "network"))
-- Whether the station should provide, request, or both. Encoded as an integer 0, 1, or 2.
combinator_api.register_setting(combinator_api.make_raw_setting("pr", "pr"))

combinator_api.register_setting(combinator_api.make_flag_setting("use_stack_thresholds", "station_flags", 0))

--------------------------------------------------------------------------------
-- Station combinator GUI.
--------------------------------------------------------------------------------

---@param event EventData.on_gui_elem_changed
---@param settings Cybersyn.Combinator.Ephemeral
local function handle_network(event, settings)
	local signal = event.element.elem_value
	local stored = nil
	if signal and signal.type == "virtual" and (not CONFIGURATION_VIRTUAL_SIGNAL_SET[signal.name]) then
		stored = signal.name
		if signal.name == "signal-everything" or signal.name == "signal-anything" or signal.name == "signal-each" then
			stored = "signal-each"
		end
	end
	combinator_api.write_setting(settings, combinator_settings.network_signal, stored)
end

---@param event EventData.on_gui_switch_state_changed
---@param settings Cybersyn.Combinator.Ephemeral
local function handle_pr_switch(event, settings)
	local element = event.element
	local is_pr_state = (element.switch_state == "none" and 0) or (element.switch_state == "left" and 1) or 2
	combinator_api.write_setting(settings, combinator_settings.pr, is_pr_state)
end

flib_gui.add_handlers(
	{
		handle_network = handle_network,
		handle_pr_switch = handle_pr_switch,
	},
	combinator_api.flib_settings_handler_wrapper,
	"station_settings"
)

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
			style_mods = { vertical_align = "center", horizontally_stretchable = true },
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
---@param changed_setting_name string?
local function update_gui(parent, settings, changed_setting_name)
	local switch_state = "none"
	local is_pr_state = combinator_api.read_setting(settings, combinator_settings.pr)
	if is_pr_state == 0 then
		switch_state = "none"
	elseif is_pr_state == 1 then
		switch_state = "left"
	elseif is_pr_state == 2 then
		switch_state = "right"
	end
	parent["is_pr_switch"].switch_state = switch_state

	local network_signal_name = combinator_api.read_setting(settings, combinator_settings.network_signal)
	local network_signal = nil
	if network_signal_name then
		network_signal = { name = network_signal_name, type = "virtual" }
	end
	parent["network_flow"]["network_button"].elem_value = network_signal

	parent["is_stack"].state = combinator_api.read_setting(settings, combinator_settings.use_stack_thresholds)
end

--------------------------------------------------------------------------------
-- Station combinator mode registration.
--------------------------------------------------------------------------------

combinator_api.register_combinator_mode({
	name = "station",
	localized_string = "cybersyn2-gui.station",
	create_gui = create_gui,
	update_gui = update_gui,
})
