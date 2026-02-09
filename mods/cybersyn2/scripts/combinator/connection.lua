-- Shared inventory connections

local events = require("lib.core.event")
local strace = require("lib.core.strace")
local tlib = require("lib.core.table")
local cs2 = _G.cs2

local EMPTY = tlib.empty

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

local function clear_all_connection_render_objects()
	for _, pstate in pairs(storage.players) do
		if pstate.connection_render_objects then
			for i = #pstate.connection_render_objects, 1, -1 do
				pstate.connection_render_objects[i].destroy()
				pstate.connection_render_objects[i] = nil
			end
			pstate.connection_render_objects = nil
		end
	end
end

---@param player LuaPlayer
local function render_connection(player)
	local pstate = cs2.get_or_create_player_state(player.index)
	local objects = pstate.connection_render_objects or {}

	for i = #objects, 1, -1 do
		objects[i].destroy()
		objects[i] = nil
	end

	local selected = player.selected
	local _ = nil
	local selected_stop = nil
	if selected then
		if selected.type == "train-stop" then
			selected_stop =
				cs2.get_stop(storage.stop_id_to_node_id[selected.unit_number or ""])
		end
	end

	local source_stop = cs2.get_stop(pstate.connection_source)

	-- If in pairing mode, draw indicators from source to potential targets.
	if source_stop then
		if selected_stop then
			draw_connection(
				objects,
				colors.teal,
				true,
				player.index,
				source_stop.entity,
				selected_stop.entity
			)
		end
		draw_connection(
			objects,
			colors.teal,
			true,
			player.index,
			source_stop.entity
		)
	end

	-- Draw connections between selected combinator and associated ones
	if selected_stop then
		local _, master_comb_id, slave_ids = selected_stop:get_sharing_info()

		if master_comb_id then
			local master_comb = cs2.get_combinator(master_comb_id, true)
			local master_stop = master_comb and master_comb:get_node() --[[@as Cybersyn.TrainStop?]]
			if master_stop and master_stop:is_valid() then
				draw_connection(
					objects,
					colors.green,
					false,
					player.index,
					selected_stop.entity,
					master_stop.entity
				)
			end
		end
		if slave_ids then
			for slave_comb_id in pairs(slave_ids) do
				local slave_comb = cs2.get_combinator(slave_comb_id, true)
				local slave_stop = slave_comb and slave_comb:get_node() --[[@as Cybersyn.TrainStop?]]
				if slave_stop and slave_stop:is_valid() then
					draw_connection(
						objects,
						colors.green,
						false,
						player.index,
						selected_stop.entity,
						slave_stop.entity
					)
				end
			end
		end
	end

	if objects[1] then
		pstate.connection_render_objects = objects
	else
		pstate.connection_render_objects = nil
	end
end

---@param player_index int
---@param source_stop_id Id
function _G.cs2.start_shared_inventory_connection(player_index, source_stop_id)
	local player = game.get_player(player_index)
	if not player then return end
	if not player.cursor_stack.can_set_stack("cybersyn2-connection-tool") then
		return
	end
	local pstate = cs2.get_or_create_player_state(player.index)
	pstate.connection_source = source_stop_id
	render_connection(player)
	-- Force player to pickup connection tool
	player.cursor_stack.set_stack("cybersyn2-connection-tool")
end

events.bind("cybersyn2-linked-clear-cursor", function(ev)
	local player = game.get_player(ev.player_index)
	if not player then return end
	local state = cs2.get_player_state(ev.player_index)
	if state then
		state.connection_source = nil
		render_connection(player)
	end
end)

events.bind("on_shutdown", function() clear_all_connection_render_objects() end)

-- Game events
-- Don't bind these in recovery mode

---@diagnostic disable-next-line: undefined-field
if _G.__RECOVERY_MODE__ then return end

events.bind(
	defines.events.on_player_selected_area,
	---@param ev EventData.on_player_selected_area
	function(ev)
		-- Sanity checks
		local player = game.get_player(ev.player_index)
		if not player then return end
		local cursor_stack = player.cursor_stack
		if
			not cursor_stack
			or not cursor_stack.valid
			or not cursor_stack.valid_for_read
		then
			return
		end
		if cursor_stack.name ~= "cybersyn2-connection-tool" then return end

		-- Find clicked stop
		if not ev.entities or (#ev.entities == 0) or (#ev.entities > 1) then
			-- TODO: error message
			return
		end
		local target_entity = ev.entities[1]
		local target_stop =
			cs2.get_stop(storage.stop_id_to_node_id[target_entity.unit_number or ""])
		if not target_stop then
			-- TODO: error message "must target a cybersyn train stop"
			player.clear_cursor()
			return
		end
		local target_combinator = target_stop:get_combinator_with_mode("station")
		if not target_combinator then
			-- TODO: error message "invalid target stop"
			player.clear_cursor()
			return
		end

		-- Finish connection
		local state = cs2.get_player_state(ev.player_index)
		if not state or not state.connection_source then
			player.clear_cursor()
			return
		end
		local source_stop = cs2.get_stop(state.connection_source)
		if not source_stop then
			player.clear_cursor()
			return
		end

		if source_stop.id == target_stop.id then
			-- TODO: error message "cannot connect to self"
			player.clear_cursor()
			return
		end

		source_stop:share_inventory_with(target_combinator)
		player.clear_cursor()
		state.connection_source = nil
		render_connection(player)
	end
)

events.bind(
	defines.events.on_selected_entity_changed,
	---@param ev EventData.on_selected_entity_changed
	function(ev)
		local player = game.get_player(ev.player_index)
		if not player then return end
		render_connection(player)
	end
)
