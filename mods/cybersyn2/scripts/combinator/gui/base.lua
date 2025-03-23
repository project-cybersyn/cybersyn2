-- Sumneko gives lots of false errors in this file due to no partial typing in
-- flib_gui's `elem_mods`.
---@diagnostic disable: missing-fields

--- @alias flib.GuiEventData EventData.on_gui_checked_state_changed|EventData.on_gui_click|EventData.on_gui_closed|EventData.on_gui_confirmed|EventData.on_gui_elem_changed|EventData.on_gui_location_changed|EventData.on_gui_opened|EventData.on_gui_selected_tab_changed|EventData.on_gui_selection_state_changed|EventData.on_gui_switch_state_changed|EventData.on_gui_text_changed|EventData.on_gui_value_changed

local flib_gui = require("__flib__.gui")
local tlib = require("__cybersyn2__.lib.table")
local log = require("__cybersyn2__.lib.logging")
local cs2 = _G.cs2
local combinator_api = _G.cs2.combinator_api
local combinator_settings = _G.cs2.combinator_settings

---Get the state for a player if that player's GUI is open. (This checks
---the stored game state's `players` table, not the actual GUI.)
---@param player_index PlayerIndex
---@return Cybersyn.PlayerState? #The GUI state for the player, or `nil` if the player's GUI is not open.
function _G.cs2.combinator_api.get_gui_state(player_index)
	local state = storage.players[player_index]
	if (not state) or not state.open_combinator then
		return nil
	end
	return state
end

---@param player_index PlayerIndex
local function destroy_gui_state(player_index)
	local state = storage.players[player_index]
	if state then
		state.open_combinator = nil
		state.open_combinator_unit_number = nil
	end
end

---@param player_index PlayerIndex
---@param combinator Cybersyn.Combinator.Ephemeral
local function create_gui_state(player_index, combinator)
	if not storage.players[player_index] then
		storage.players[player_index] = {
			player_index = player_index,
			open_combinator = nil,
			open_combinator_unit_number = nil,
		}
	end
	storage.players[player_index].open_combinator = combinator
	storage.players[player_index].open_combinator_unit_number =
		combinator.entity.unit_number
end

---Determine if a player has the combinator GUI open.
---@param player_index PlayerIndex
---@return boolean
function _G.cs2.combinator_api.is_gui_open(player_index)
	local player = game.get_player(player_index)
	if not player then
		return false
	end
	local gui_root = player.gui.screen
	local combinator_ui = combinator_api.get_gui_state(player_index)
	if combinator_ui or gui_root[cs2.WINDOW_NAME] then
		return true
	else
		return false
	end
end

---Close the combinator gui for the given player.
---@param player_index PlayerIndex
---@param silent boolean?
function _G.cs2.combinator_api.close_gui(player_index, silent)
	local player = game.get_player(player_index)
	if not player then
		return
	end
	local gui_root = player.gui.screen
	if gui_root[cs2.WINDOW_NAME] then
		gui_root[cs2.WINDOW_NAME].destroy()
		if not silent then
			player.play_sound({ path = cs2.COMBINATOR_CLOSE_SOUND })
		end
	end
	destroy_gui_state(player_index)
end

---@param window LuaGuiElement
---@param settings Cybersyn.Combinator.Ephemeral
local function rebuild_mode_section(window, settings)
	if (not window) or (window.name ~= cs2.WINDOW_NAME) then
		return
	end
	local mode_section = window["frame"]["vflow"]["mode_settings"]
	local mode_dropdown = window["frame"]["vflow"]["mode_flow"]["mode_dropdown"]

	-- TODO: fix this
	-- internal_update_combinator_gui_status_section(window, settings)

	-- Impose desired mode from combinator settiongs
	local desired_mode_name =
		combinator_api.read_setting(settings, combinator_settings.mode)
	local desired_mode = combinator_api.get_combinator_mode(desired_mode_name)
	if not desired_mode then
		-- Invalid mode
		mode_section.clear()
		mode_dropdown.selected_index = 0
		return
	end

	-- Impose mode on dropdown
	local _, desired_mode_index = tlib.find(
		combinator_api.get_combinator_mode_list(),
		function(x)
			return x == desired_mode_name
		end
	)
	if desired_mode_index then
		mode_dropdown.selected_index = desired_mode_index
	end

	-- Impose mode on lower GUI section
	-- If GUI for mode is already built, update it.
	if mode_section.tags.current_mode == desired_mode then
		desired_mode.update_gui(mode_section, settings)
		return
	end
	-- Teardown the old mode section and rebuild/update
	mode_section.clear()
	desired_mode.create_gui(mode_section)
	mode_section.tags.current_mode = desired_mode
	desired_mode.update_gui(mode_section, settings)
end

---@param window LuaGuiElement
---@param settings Cybersyn.Combinator.Ephemeral
---@param updated_setting string?
local function update_mode_section(window, settings, updated_setting)
	if (not window) or (window.name ~= cs2.WINDOW_NAME) then
		return
	end
	local mode_section = window["frame"]["vflow"]["mode_settings"]
	local desired_mode_name =
		combinator_api.read_setting(settings, combinator_settings.mode)
	local desired_mode = combinator_api.get_combinator_mode(desired_mode_name)
	if
		not desired_mode or (mode_section.tags.current_mode ~= desired_mode_name)
	then
		return rebuild_mode_section(window, settings)
	end
	desired_mode.update_gui(mode_section, settings, updated_setting)
end

---Run a callback on each player who has an open combinator GUI.
---@param callback fun(state: Cybersyn.PlayerState, ui_root: LuaGuiElement)
function _G.cs2.combinator_api.for_each_open_combinator_gui(callback)
	for _, state in pairs(storage.players) do
		local player = game.get_player(state.player_index)
		if player then
			local comb_gui = player.gui.screen[cs2.WINDOW_NAME]
			if comb_gui then
				callback(state, comb_gui)
			end
		end
	end
end

local function close_guis_with_invalid_combinators()
	combinator_api.for_each_open_combinator_gui(function(state)
		local comb = state.open_combinator
		if not comb or not combinator_api.is_valid(comb) then
			combinator_api.close_gui(state.player_index)
		end
	end)
end

---@param settings Cybersyn.Combinator.Ephemeral
local function rebuild_mode_sections(settings)
	local comb_unit_number = settings.entity.unit_number
	combinator_api.for_each_open_combinator_gui(function(ui_state, comb_gui)
		if ui_state.open_combinator_unit_number == comb_unit_number then
			rebuild_mode_section(comb_gui, settings)
		end
	end)
end

---@param settings Cybersyn.Combinator.Ephemeral
local function update_mode_sections(settings, updated_setting)
	local comb_unit_number = settings.entity.unit_number
	combinator_api.for_each_open_combinator_gui(function(ui_state, comb_gui)
		if ui_state.open_combinator_unit_number == comb_unit_number then
			update_mode_section(comb_gui, settings, updated_setting)
		end
	end)
end

---Generic flib wrapper to attach setting and gui info before calling the
---handler function.
---@param event flib.GuiEventData
---@param handler function
function _G.cs2.combinator_api.flib_settings_handler_wrapper(event, handler)
	local player = game.get_player(event.player_index)
	if not player then
		return
	end
	local gui_root = player.gui.screen[cs2.WINDOW_NAME]
	if not gui_root then
		return
	end
	local state = combinator_api.get_gui_state(event.player_index)
	if
		state
		and state.open_combinator
		and combinator_api.is_valid(state.open_combinator)
	then
		local mode_section = gui_root["frame"]["vflow"]["mode_settings"]
		handler(event, state.open_combinator, mode_section, player, state, gui_root)
	end
end

---Generic flib handler to handle toggling a flag based setting.
---@param event flib.GuiEventData
---@param settings Cybersyn.Combinator.Ephemeral
function _G.cs2.combinator_api.generic_checkbox_handler(event, settings)
	local elt = event.element
	if not elt then
		return
	end
	local setting = elt.tags.setting
	local inverted = elt.tags.inverted
	local new_value = event.element.state
	if inverted then
		new_value = not new_value
	end
	combinator_api.write_setting(
		settings,
		combinator_settings[setting],
		new_value
	)
end

---@param e EventData.on_gui_click
local function handle_close(e)
	combinator_api.close_gui(e.player_index)
end

---@param e EventData.on_gui_selection_state_changed
local function handle_mode_dropdown(e)
	local state = combinator_api.get_gui_state(e.player_index)
	if
		state
		and state.open_combinator
		and combinator_api.is_valid(state.open_combinator)
	then
		local new_mode =
			combinator_api.get_combinator_mode_list()[e.element.selected_index]
		if not new_mode then
			return
		end
		combinator_api.write_setting(
			state.open_combinator,
			combinator_settings.mode,
			new_mode
		)
	end
end

---@param player_index PlayerIndex
---@param combinator Cybersyn.Combinator.Ephemeral
function _G.cs2.combinator_api.open_gui(player_index, combinator)
	if not combinator_api.is_valid(combinator) then
		return
	end
	local player = game.get_player(player_index)
	if not player then
		return
	end
	-- Close any existing gui
	combinator_api.close_gui(player_index, true)
	-- Create new gui state
	create_gui_state(player_index, combinator)

	-- Generate main gui window
	local gui_root = player.gui.screen
	local mode_dropdown_items = tlib.map(
		combinator_api.get_combinator_mode_list(),
		function(mode_name)
			local mode = combinator_api.get_combinator_mode(mode_name)
			return { mode.localized_string }
		end
	)
	if #mode_dropdown_items == 0 then
		mode_dropdown_items = { "unknown" }
	end
	local _, main_window = flib_gui.add(gui_root, {
		{
			type = "frame",
			direction = "vertical",
			name = cs2.WINDOW_NAME,
			children = {
				--title bar
				{
					type = "flow",
					name = "titlebar",
					children = {
						{
							type = "label",
							style = "frame_title",
							caption = { "cybersyn-gui.combinator-title" },
							elem_mods = { ignored_by_interaction = true },
						},
						{
							type = "empty-widget",
							style = "flib_titlebar_drag_handle",
							elem_mods = { ignored_by_interaction = true },
						},
						{
							type = "sprite-button",
							style = "frame_action_button",
							mouse_button_filter = { "left" },
							sprite = "utility/close",
							hovered_sprite = "utility/close",
							handler = handle_close,
						},
					},
				},
				{
					type = "frame",
					name = "frame",
					style = "inside_shallow_frame_with_padding",
					style_mods = { padding = 12, bottom_padding = 9 },
					children = {
						{
							type = "flow",
							name = "vflow",
							direction = "vertical",
							style_mods = { horizontal_align = "left" },
							children = {
								{
									name = "statuses",
									type = "flow",
									direction = "vertical",
									style_mods = {
										bottom_padding = 4,
									},
								},
								--preview
								{
									type = "frame",
									name = "preview_frame",
									style = "deep_frame_in_shallow_frame",
									style_mods = {
										minimal_width = 0,
										horizontally_stretchable = true,
										padding = 0,
									},
									children = {
										{
											type = "entity-preview",
											name = "preview",
											style = "wide_entity_button",
										},
									},
								},
								--mode picker
								{
									type = "label",
									style = "heading_2_label",
									caption = { "cybersyn-gui.operation" },
									style_mods = { top_padding = 8 },
								},
								{
									type = "flow",
									name = "mode_flow",
									direction = "horizontal",
									style_mods = { vertical_align = "center" },
									children = {
										{
											type = "drop-down",
											name = "mode_dropdown",
											style_mods = { top_padding = 3, right_margin = 8 },
											handler = handle_mode_dropdown,
											selected_index = 1,
											items = mode_dropdown_items,
										},
									},
								},
								---Settings section for modal settings
								{
									type = "flow",
									name = "mode_settings",
									direction = "vertical",
									tags = { current_mode = "" },
									style_mods = { horizontal_align = "left" },
									children = {}, -- children
								}, -- mode_settings
							}, -- children
						}, -- vflow
					}, -- children
				}, -- frame
			}, -- children
		}, -- window
	})

	main_window.titlebar.drag_target = main_window
	main_window.force_auto_center()

	rebuild_mode_section(main_window, combinator)

	player.opened = main_window
end

--------------------------------------------------------------------------------
-- Event handling
--------------------------------------------------------------------------------
flib_gui.add_handlers({
	["comb_close"] = handle_close,
	["comb_mode"] = handle_mode_dropdown,
})

flib_gui.add_handlers({
	["generic_checkbox_handler"] = combinator_api.generic_checkbox_handler,
}, combinator_api.flib_settings_handler_wrapper)

-- When a combinator ghost revives, close any guis that may be referencing it.
-- (We're doing this every time a combinator is built which is overkill but
-- there doesn't appear to be a precise event for ghost revival.)
cs2.on_built_combinator(close_guis_with_invalid_combinators)

-- Repaint GUIs when a combinator's settings change.
cs2.on_combinator_or_ghost_setting_changed(function(combinator, setting_name)
	if setting_name == nil or setting_name == "mode" then
		rebuild_mode_sections(combinator)
	else
		update_mode_sections(combinator, setting_name)
	end
end)
