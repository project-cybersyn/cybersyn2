local log = require("__cybersyn2__.lib.logging")
local relm = require("__cybersyn2__.lib.relm")
local relm_helpers = require("__cybersyn2__.lib.relm-helpers")
local ultros = require("__cybersyn2__.lib.ultros")
local tlib = require("__cybersyn2__.lib.table")
local mgr = _G.mgr

local Pr = relm.Primitive

---@class Cybersyn2.Manager.InspectorFrameType
---@field public name string Type of this panel
---@field public widget_type string CSGUI widget to create.

_G.mgr.inspector = {}
_G.mgr.INSPECTOR_WINDOW_NAME = "cybersyn2-inspector"
local inspector = _G.mgr.inspector

---Get open inspector window for given player.
---@return Relm.RootId? root_id Relm root id of open inspector
---@return LuaGuiElement? element Factorio element of open inspector
function _G.mgr.inspector.get(player_index)
	local player = game.get_player(player_index)
	if not player then return end
	return storage.inspector_root[player_index],
		player.gui.screen[mgr.INSPECTOR_WINDOW_NAME]
end

function _G.mgr.inspector.close(player_index)
	local id, window = inspector.get(player_index)
	if id then relm.root_destroy(id) end
	if window and window.valid then window.destroy() end
	storage.inspector_root[player_index] = nil
end

---Open inspector for player if not already open.
---@param player_index uint
---@return Relm.RootId? id If a window was opened, the id of the new root.
function _G.mgr.inspector.open(player_index)
	local player = game.get_player(player_index)
	if not player then return end
	local screen = player.gui.screen

	if
		(not inspector.get(player_index))
		and not screen[mgr.INSPECTOR_WINDOW_NAME]
	then
		local id = relm.root_create(
			screen,
			"CybersynInspector",
			"Cybersyn.Inspector",
			{ player_index = player_index }
		)
		storage.inspector_root[player_index] = id
	end
end

---@class Cybersyn.Manager.InspectorEntry
---@field public type string
---@field public key string Unique key to avoid dupe entries.
---@field public caption string

---@param player_index uint
---@param entry Cybersyn.Manager.InspectorEntry[]
function _G.mgr.inspector.add_entries(player_index, entry)
	local root = inspector.get(player_index)
	if not root then return end
	relm.msg_broadcast(
		relm.root_handle(root),
		{ key = "add_entries", entries = entry }
	)
end

---@param entity LuaEntity
---@return Cybersyn.Manager.InspectorEntry[]?
local function entity_to_entries(entity)
	if entity.name == "train-stop" then
		return {
			{
				key = "stop" .. entity.unit_number,
				type = "InspectorItem.Generic",
				query = {
					type = "stops",
					unit_numbers = { entity.unit_number },
				},
				caption = "TrainStop " .. entity.unit_number,
			},
		}
	elseif entity.name == "cybersyn2-combinator" then
		return {
			{
				key = "comb" .. entity.unit_number,
				type = "InspectorItem.Generic",
				query = {
					type = "combinators",
					ids = { entity.unit_number },
				},
				caption = "Combinator " .. entity.unit_number,
			},
		}
	end
end

mgr.on_inspector_selected(function(event)
	if not inspector.get(event.player_index) then
		inspector.open(event.player_index)
	end
	local entries = tlib.flat_map(event.entities, entity_to_entries)
	inspector.add_entries(event.player_index, entries)
end)

--------------------------------------------------------------------------------
-- Components
--------------------------------------------------------------------------------

relm.define_element({
	name = "InspectorItem.Generic",
	render = function(props)
		relm_helpers.use_timer(120, "update")
		local result = remote.call("cybersyn2", "query", props.query)
		return ultros.RtMultilineLabel(log.stringify(result))
	end,
	message = function(me, payload)
		if payload.key == "update" then
			relm.paint(me)
			return true
		end
		return false
	end,
})

local Entry = relm.define_element({
	name = "Cybersyn.Inspector.Entry",
	render = function(props, state)
		local entry = props.entry
		if not entry then return nil end
		-- Update logic is delegated to the type widget, as some might be
		-- able to smartly bind to events.
		return ultros.WellSection({
			caption = entry.caption,
			decorate = function() return ultros.CloseButton() end,
		}, {
			relm.element(entry.type, entry),
		})
	end,
	message = function(me, payload, props)
		-- Close logic here
		if payload.key == "close" then
			relm.msg_bubble(
				me,
				{ key = "remove_entries", entries = { props.key } },
				true
			)
			return true
		end
		return false
	end,
})

local Entries = relm.define_element({
	name = "Cybersyn.Inspector.Entries",
	---@param state table
	render = function(props, state)
		local children = tlib.t_map_a(
			state or {},
			function(v) return Entry({ key = v.key, entry = v }) end
		)
		log.trace("entries", children)
		return children
	end,
	state = function() return {} end,
	message = function(me, payload, _, state)
		if payload.key == "add_entries" then
			local next_state = tlib.assign({}, state)
			for _, v in pairs(payload.entries) do
				next_state[v.key] = v
			end
			relm.set_state(me, next_state)
			return true
		elseif payload.key == "remove_entries" then
			local next_state = tlib.assign({}, state)
			for _, v in pairs(payload.entries) do
				next_state[v] = nil
			end
			relm.set_state(me, next_state)
			return true
		end
		return false
	end,
})

relm.define_element({
	name = "Cybersyn.Inspector",
	render = function(props)
		return ultros.WindowFrame({
			caption = "Cybersyn Inspector",
		}, {
			Pr({
				type = "frame",
				style = "inside_shallow_frame",
				direction = "vertical",
				vertically_stretchable = true,
				width = 400,
				minimal_height = 300,
				maximal_height = 600,
			}, {
				Pr({
					type = "scroll-pane",
					direction = "vertical",
					horizontally_stretchable = true,
					vertically_stretchable = true,
					vertical_scroll_policy = "always",
					horizontal_scroll_policy = "never",
					extra_top_padding_when_activated = 0,
					extra_left_padding_when_activated = 0,
					extra_right_padding_when_activated = 0,
					extra_bottom_padding_when_activated = 0,
				}, {
					Entries(),
				}),
			}),
		})
	end,
	message = function(me, payload, props)
		if payload.key == "close" then
			inspector.close(props.player_index)
			return true
		end
		return false
	end,
})
