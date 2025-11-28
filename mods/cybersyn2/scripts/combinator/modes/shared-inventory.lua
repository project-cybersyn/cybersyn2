--------------------------------------------------------------------------------
-- Shared inventory combinator
--------------------------------------------------------------------------------

local tlib = require("lib.core.table")
local mlib = require("lib.core.math.bbox")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_helpers = require("lib.core.relm.util")
local stlib = require("lib.core.strace")
local cs2 = _G.cs2
local cs2_lib = _G.cs2.lib
local combinator_settings = _G.cs2.combinator_settings
local gui = _G.cs2.gui

local strace = stlib.strace
local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local STATUS_SHARED_NONE = { color = "red", caption = "No shared inventory" }
local STATUS_SHARED_MASTER =
	{ color = "green", caption = "Sharing my inventory" }
local STATUS_SHARED_SLAVE =
	{ color = "green", caption = "Receiving shared inventory" }

---@param stop Cybersyn.TrainStop
local function get_status_props(stop)
	if stop.shared_inventory_master then
		return STATUS_SHARED_SLAVE
	elseif stop.shared_inventory_slaves then
		return STATUS_SHARED_MASTER
	else
		return STATUS_SHARED_NONE
	end
end

relm.define_element({
	name = "CombinatorGui.Mode.SharedInventory",
	render = function(props)
		relm_helpers.use_event("on_train_stop_shared_inventory_changed")
		local combinator = props.combinator:realize() --[[@as Cybersyn.Combinator]]
		local stop = cs2.get_stop(combinator and combinator.node_id or 0)
		if not stop then
			strace(
				stlib.WARN,
				"message",
				"Shared inventory combinator without associated train stop",
				combinator
			)
			return ultros.RtMultilineLabel("No associated train stop found.")
		end
		return ultros.WellSection(
			{ caption = { "cybersyn2-combinator-modes-labels.settings" } },
			{
				gui.Status(get_status_props(stop)),
				ultros.If(
					stop:is_sharing_inventory(),
					ultros.Button({
						caption = "Stop sharing inventory",
						on_click = "stop_sharing",
					})
				),
				ultros.If(
					not stop:is_sharing_inventory(),
					ultros.Button({
						caption = "Create new shared inventory",
						on_click = "share_inventory",
					})
				),
				ultros.If(
					not stop:is_sharing_master() and not stop.shared_inventory_master,
					ultros.Button({
						caption = "Connect to existing shared inventory",
						on_click = "make_connection",
					})
				),
				ultros.If(
					stop:is_sharing_master(),
					ultros.Button({
						caption = "Connect another stop to this shared inventory",
						on_click = "make_connection",
					})
				),
			}
		)
	end,
	message = function(me, payload, props)
		if payload.key == "on_train_stop_shared_inventory_changed" then
			relm.paint(me)
			return true
		elseif payload.key == "make_connection" then
			cs2.start_connection(payload.event.player_index, props.combinator.entity)
			return true
		elseif payload.key == "share_inventory" then
			local combinator = props.combinator:realize() --[[@as Cybersyn.Combinator]]
			local stop = cs2.get_stop(combinator and combinator.node_id or 0)
			if not stop then return true end
			if stop:is_sharing_inventory() then return true end
			stop:share_inventory()
			return true
		elseif payload.key == "stop_sharing" then
			local combinator = props.combinator:realize() --[[@as Cybersyn.Combinator]]
			local stop = cs2.get_stop(combinator and combinator.node_id or 0)
			if not stop then return true end
			stop:stop_sharing_inventory()
			return true
		else
			return false
		end
	end,
})

relm.define_element({
	name = "CombinatorGui.Mode.SharedInventory.Help",
	render = function(props)
		return VF({
			ultros.RtMultilineLabel({
				"cybersyn2-combinator-mode-shared-inventory.desc",
			}),
		})
	end,
})

--------------------------------------------------------------------------------
-- Mode registration
--------------------------------------------------------------------------------

-- cs2.register_combinator_mode({
-- 	name = "shared-inventory",
-- 	localized_string = "cybersyn2-combinator-modes.shared-inventory",
-- 	settings_element = "CombinatorGui.Mode.SharedInventory",
-- 	help_element = "CombinatorGui.Mode.SharedInventory.Help",
-- })

--------------------------------------------------------------------------------
-- Connection creation and visualization
-- Based on https://github.com/raiguard/EditorExtensions/blob/master/scripts/linked-belt.lua
--------------------------------------------------------------------------------

--- @type table<string, Color>
local colors = {
	red = { r = 1, g = 0.5, b = 0.5 },
	green = { r = 0.3, g = 0.8, b = 0.3 },
	teal = { r = 0.5, g = 1, b = 1 },
}

--- @param objects LuaRenderObject[]
--- @param color Color
--- @param dashed boolean
--- @param player_index uint
--- @param source LuaEntity
--- @param destination LuaEntity?
local function draw_connection(
	objects,
	color,
	dashed,
	player_index,
	source,
	destination
)
	for _, entity in pairs({ source, destination }) do
		objects[#objects + 1] = rendering.draw_circle({
			color = color,
			radius = 0.15,
			width = 2,
			filled = not dashed,
			target = entity.position,
			surface = entity.surface,
			players = { player_index },
		})
	end
	if destination and source.surface == destination.surface then
		objects[#objects + 1] = rendering.draw_line({
			color = color,
			width = 2,
			gap_length = dashed and 0.3 or 0,
			dash_length = dashed and 0.3 or 0,
			from = source.position,
			to = destination.position,
			surface = source.surface,
			players = { player_index },
		})
	end
end

--- @param player LuaPlayer
local function render_connection(player)
	local pstate = cs2.get_or_create_player_state(player.index)
	local objects = pstate.connection_render_objects or {}

	for i = #objects, 1, -1 do
		objects[i].destroy()
		objects[i] = nil
	end

	local csun = (pstate.connection_source and pstate.connection_source.valid)
			and pstate.connection_source.unit_number
		or nil
	local source_combinator = cs2.get_combinator(csun)
	local selected_combinator =
		cs2.get_combinator(player.selected and player.selected.unit_number or nil)
	if selected_combinator and selected_combinator.mode ~= "shared-inventory" then
		selected_combinator = nil
	end

	-- Draw connections between selected combinator and associated ones
	if selected_combinator then
		local stop = cs2.get_stop(selected_combinator.node_id)
		if stop and stop.shared_inventory_slaves then
			for slave_id in pairs(stop.shared_inventory_slaves) do
				local slave_stop = cs2.get_stop(slave_id)
				if slave_stop then
					local slave_combinator =
						slave_stop:get_combinator_with_mode("shared-inventory")
					if slave_combinator then
						draw_connection(
							objects,
							colors.green,
							false,
							player.index,
							selected_combinator.entity,
							slave_combinator.entity
						)
					end
				end
			end
		elseif stop and stop.shared_inventory_master then
			local master_stop = cs2.get_stop(stop.shared_inventory_master)
			if master_stop then
				local master_combinator =
					master_stop:get_combinator_with_mode("shared-inventory")
				if master_combinator then
					draw_connection(
						objects,
						colors.green,
						false,
						player.index,
						selected_combinator.entity,
						master_combinator.entity
					)
				end
			end
		end
	end

	-- If in pairing mode, draw indicators from source to potential targets.
	if source_combinator then
		if selected_combinator then
			draw_connection(
				objects,
				colors.teal,
				true,
				player.index,
				source_combinator.entity,
				selected_combinator.entity
			)
		end
		draw_connection(
			objects,
			colors.teal,
			true,
			player.index,
			source_combinator.entity
		)
	end

	if objects[1] then
		pstate.connection_render_objects = objects
	else
		pstate.connection_render_objects = nil
	end
end

---@param player LuaPlayer
---@param entity LuaEntity
local function start_connection(player, entity)
	local pstate = cs2.get_or_create_player_state(player.index)
	pstate.connection_source = entity
	render_connection(player)
end

---@param player LuaPlayer
---@param entity LuaEntity
local function finish_connection(player, entity)
	local pstate = cs2.get_or_create_player_state(player.index)
	local csun = (pstate.connection_source and pstate.connection_source.valid)
			and pstate.connection_source.unit_number
		or nil
	local source_combinator = cs2.get_combinator(csun)
	if
		not source_combinator or (source_combinator.mode ~= "shared-inventory")
	then
		return
	end
	local source_stop = cs2.get_stop(source_combinator.node_id)
	if not source_stop then return end

	local target_combinator = cs2.get_combinator(entity.unit_number)
	if not target_combinator or target_combinator.mode ~= "shared-inventory" then
		cs2_lib.flying_text(
			player,
			"Not a shared inventory combinator",
			true,
			entity.position
		)
		return
	end
	local target_stop = cs2.get_stop(target_combinator.node_id)
	if not target_stop then
		cs2_lib.flying_text(
			player,
			"Can't find associated stop",
			true,
			entity.position
		)
		return
	end
	if target_stop.id == source_stop.id then
		cs2_lib.flying_text(player, "Can't link to self", true, entity.position)
		return
	end

	local master_stop = nil
	local slave_stop = nil
	if source_stop.shared_inventory_slaves then
		master_stop = source_stop
		slave_stop = target_stop
	elseif target_stop.shared_inventory_slaves then
		master_stop = target_stop
		slave_stop = source_stop
	else
		cs2_lib.flying_text(player, "Invalid link target", true, entity.position)
		return
	end

	if slave_stop.shared_inventory_master then
		cs2_lib.flying_text(
			player,
			"Already linked to a master inventory. Clear existing link first.",
			true,
			slave_stop.entity.position
		)
		return
	end

	master_stop:share_inventory_with(slave_stop)

	render_connection(player)
end

---@param player LuaPlayer
local function cancel_connection(player)
	local pstate = cs2.get_player_state(player.index)
	if not pstate then return end
	pstate.connection_source = nil
	render_connection(player)
end

cs2.on_cursor_cleared(cancel_connection)
cs2.on_selected(function(_, _, player) render_connection(player) end)

---Spaghetti code interceptor for the `on_gui_opened` event to check if an
---attempt to create a link is being made.
---@return boolean #`true` if there was a connection attempt
function _G.cs2.try_finish_connection(player, entity)
	if not cs2_lib.entity_is_combinator(entity) then return false end
	local pstate = cs2.get_player_state(player.index)
	if (not pstate) or not pstate.connection_source then return false end
	finish_connection(player, entity)
	pstate.connection_source = nil
	return true
end

---Start connection entry point. Called from within the shared inventory comb
---GUI. Closes the GUI and triggers the connection start.
---@param player_index PlayerIndex
---@param combinator_entity LuaEntity
function _G.cs2.start_connection(player_index, combinator_entity)
	local player = game.get_player(player_index)
	if not player then return end
	cs2.lib.close_combinator_gui(player_index)
	start_connection(player, combinator_entity)
end
