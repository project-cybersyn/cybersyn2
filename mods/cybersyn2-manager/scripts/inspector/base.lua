local flib_gui = require("__flib__.gui")
local cs_gui = require("__cybersyn2__.lib.gui")
local log = require("__cybersyn2__.lib.logging")
local mgr = _G.mgr

---@class Cybersyn2.Manager.InspectorFrameType
---@field public name string Type of this panel
---@field public widget_type string CSGUI widget to create.

_G.mgr.inspector = {}
_G.mgr.INSPECTOR_WINDOW_NAME = "cybersyn2-inspector"
local inspector = _G.mgr.inspector

---@param player_index uint
---@param no_create boolean?
---@return Cybersyn.Manager.InspectorState?
local function get_or_create_inspector_state(player_index, no_create)
	local pstate = storage.players[player_index]
	if not pstate then
		storage.players[player_index] = {}
		pstate = storage.players[player_index]
	end
	local istate = pstate.inspector
	if not istate and not no_create then
		pstate.inspector = {
			entries = {},
		}
		istate = pstate.inspector
	end
	return istate
end

function _G.mgr.inspector.close(player_index)
	local player = game.get_player(player_index)
	if not player then return end
	local gui_root = player.gui.screen
	if gui_root[mgr.INSPECTOR_WINDOW_NAME] then
		gui_root[mgr.INSPECTOR_WINDOW_NAME].destroy()
	end
	destroy_inspector_state(player_index)
end

---Open a new inspector for the given player. Destroys any existing inspector;
---call `inspector.get_window` to check if one is already open.
---@param player_index uint
function _G.mgr.inspector.open(player_index)
	local player = game.get_player(player_index)
	if not player then return end

	-- Close existing inspectors
	inspector.close(player_index)
	get_or_create_inspector_state(player_index)
end

function _G.mgr.inspector.update_layout(player_index)
	local window = inspector.get_window(player_index)
	if not window then return end
	local state = get_or_create_inspector_state(player_index, true)
	if not state then return end

	-- Create inspector frames for each inspected object.
	local widget_ctr = window["widgets"]
	for i = 1, #state.entries do
		if not widget_ctr.children[i] then
			local widget = cs_gui.create_widget(state.entries[i].type, { index = i })
			widget.index = i
			flib_gui.add(widget_ctr, widget)
		end
	end
	for i = #state.entries + 1, #widget_ctr.children do
		widget_ctr.children[i].destroy()
	end

	mgr.inspector.update_frames(player_index)
end

function _G.mgr.inspector.update_frames(player_index)
	local window = inspector.get_window(player_index)
	if not window then return end
	local state = get_or_create_inspector_state(player_index, true)
	if not state then return end
	local widget_ctr = window["widgets"]
	-- Apply results data to widget frames
	for i = 1, #state.entries do
		local entry = state.entries[i]
		local widget = widget_ctr.children[i]
		if not widget then break end
		cs_gui.update_widget(widget, entry)
	end
end

---@param player_index uint
---@param entry Cybersyn.Manager.InspectorEntry
function _G.mgr.inspector.add_entry(player_index, entry)
	local state = get_or_create_inspector_state(player_index, true)
	if not state then return end
	table.insert(state.entries, entry)
	inspector.update_layout(player_index)
end

---@param player_index uint
---@param entry_index uint
function _G.mgr.inspector.remove_entry(player_index, entry_index)
	local state = get_or_create_inspector_state(player_index, true)
	if not state then return end
	if not state.entries[entry_index] then return end
	table.remove(state.entries, entry_index)
	inspector.update_layout(player_index)
end

---@param player_index uint
---@param entity LuaEntity
local function add_entity_queries(player_index, entity)
	if entity.name == "train-stop" then
		mgr.inspector.add_entry(player_index, {
			query = {
				type = "stops",
				unit_numbers = { entity.unit_number },
			},
			caption = "TrainStop " .. entity.unit_number,
		})
	elseif entity.name == "cybersyn2-combinator" then
		mgr.inspector.add_entry(player_index, {
			query = {
				type = "combinators",
				ids = { entity.unit_number },
			},
			caption = "Combinator " .. entity.unit_number,
		})
	end
end

mgr.on_inspector_selected(function(event)
	if not inspector.get_window(event.player_index) then
		inspector.open(event.player_index)
	end
	for i = 1, #event.entities do
		local entity = event.entities[i]
		add_entity_queries(event.player_index, entity)
	end
end)
