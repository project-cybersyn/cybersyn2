--------------------------------------------------------------------------------
-- Main entry point.
--------------------------------------------------------------------------------

local events = require("lib.core.event")
local tlib = require("lib.core.table")
local cs2 = _G.cs2
local cs2_lib = _G.cs2.lib

-- If in recovery mode, do not bind to events. This allows the mod to be loaded and the state to be inspected or reset without being mutated.
if _G.__RECOVERY_MODE__ then return end

--------------------------------------------------------------------------------
-- LuaTrains
--------------------------------------------------------------------------------

events.bind(defines.events.on_train_created, cs2.raise_luatrain_created)
events.bind(
	defines.events.on_train_changed_state,
	cs2.raise_luatrain_changed_state
)

--------------------------------------------------------------------------------
-- Entity construction
--------------------------------------------------------------------------------

---@param event EventData.script_raised_built|EventData.script_raised_revive|EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_entity_cloned|EventData.on_space_platform_built_entity
local function on_built(event)
	local entity = event.entity or event.destination
	if not entity or not entity.valid then return end

	if entity.name == "train-stop" then
		cs2.raise_built_train_stop(entity)
	elseif
		entity.type == "straight-rail"
		or entity.type == "curved-rail-a"
		or entity.type == "curved-rail-b"
	then
		cs2.raise_built_rail(entity)
	elseif
		cs2.lib.is_equipment_type(entity.type)
		or cs2.lib.is_equipment_name(entity.name)
	then
		cs2.raise_built_equipment(entity)
	end
end

local filter_built = {
	{ filter = "name", name = "train-stop" },
	{ filter = "type", type = "straight-rail" },
	{ filter = "type", type = "curved-rail-a" },
	{ filter = "type", type = "curved-rail-b" },
}
for _, type in ipairs(cs2.lib.get_equipment_types()) do
	table.insert(filter_built, { filter = "type", type = type })
end
for _, name in ipairs(cs2.lib.get_equipment_names()) do
	table.insert(filter_built, { filter = "name", name = name })
end

events.bind(defines.events.on_built_entity, on_built, nil, filter_built)
events.bind(defines.events.on_robot_built_entity, on_built, nil, filter_built)
events.bind(
	defines.events.on_space_platform_built_entity,
	on_built,
	nil,
	filter_built
)
events.bind(defines.events.script_raised_built, on_built)
events.bind(defines.events.script_raised_revive, on_built)
events.bind(defines.events.on_entity_cloned, on_built)

--------------------------------------------------------------------------------
-- Entity configuration
--------------------------------------------------------------------------------

---@param event EventData.on_player_rotated_entity
local function on_repositioned(event)
	local entity = event.entity
	if not entity or not entity.valid then return end

	if entity.type == "inserter" then
		cs2.raise_entity_repositioned("inserter", entity)
	end
end

---@param event EventData.on_entity_renamed
local function on_renamed(event)
	if event.entity.name == "train-stop" then
		cs2.raise_entity_renamed("train-stop", event.entity, event.old_name)
	end
end

events.bind(defines.events.on_player_rotated_entity, on_repositioned)
events.bind(defines.events.on_entity_renamed, on_renamed)
events.bind(
	defines.events.on_entity_settings_pasted,
	cs2.raise_entity_settings_pasted
)

events.bind(defines.events.on_selected_entity_changed, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end
	local entity = player.selected
	if
		(event.last_entity and cs2_lib.entity_is_combinator(event.last_entity))
		or (entity and cs2_lib.entity_is_combinator(entity))
	then
		cs2.raise_selected(entity, event.last_entity, player)
	end
end)

events.bind(
	"cybersyn2-linked-clear-cursor",
	---@param event EventData.CustomInputEvent
	function(event)
		local player = game.get_player(event.player_index)
		if not player then return end
		cs2.raise_cursor_cleared(player)
	end
)

--------------------------------------------------------------------------------
-- Entity destruction
--------------------------------------------------------------------------------

---@param event EventData.on_entity_died|EventData.on_pre_player_mined_item|EventData.on_robot_pre_mined|EventData.on_space_platform_pre_mined|EventData.script_raised_destroy
local function on_destroyed(event)
	local entity = event.entity
	if not entity or not entity.valid then return end

	if entity.name == "train-stop" then
		cs2.raise_broken_train_stop(entity)
	elseif
		entity.type == "straight-rail"
		or entity.type == "curved-rail-a"
		or entity.type == "curved-rail-b"
	then
		cs2.raise_broken_rail(entity)
	elseif
		cs2.lib.is_equipment_type(entity.type)
		or cs2.lib.is_equipment_name(entity.name)
	then
		cs2.raise_broken_equipment(entity)
	elseif entity.train then
		-- Rolling stock.
		cs2.raise_broken_train_stock(entity, entity.train)
	end
end

local filter_broken = tlib.assign({}, filter_built)
table.insert(filter_broken, { filter = "rolling-stock" })

events.bind(defines.events.on_entity_died, on_destroyed, nil, filter_broken)
events.bind(
	defines.events.on_pre_player_mined_item,
	on_destroyed,
	nil,
	filter_broken
)
events.bind(defines.events.on_robot_pre_mined, on_destroyed, nil, filter_broken)
events.bind(
	defines.events.on_space_platform_pre_mined,
	on_destroyed,
	nil,
	filter_broken
)
events.bind(defines.events.script_raised_destroy, on_destroyed)

--------------------------------------------------------------------------------
-- Surfaces
--------------------------------------------------------------------------------

events.bind(
	defines.events.on_pre_surface_cleared,
	function(event) cs2.raise_surface(event.surface_index, "cleared") end
)
events.bind(
	defines.events.on_pre_surface_deleted,
	function(event) cs2.raise_surface(event.surface_index, "deleted") end
)
events.bind(
	defines.events.on_surface_created,
	function(event) cs2.raise_surface(event.surface_index, "created") end
)

--------------------------------------------------------------------------------
-- Combinator GUI
--------------------------------------------------------------------------------

events.bind(
	defines.events.on_gui_opened,
	---@param event EventData.on_gui_opened
	function(event)
		if not event.entity then return end
		local player = game.get_player(event.player_index)
		if not player then return end
		local _, id = remote.call("things", "get_thing_id", event.entity)
		local comb = cs2.get_combinator(id)
		if not comb then return end

		cs2.open_combinator_gui(event.player_index, comb)
	end
)

events.bind(defines.events.on_gui_closed, function(event)
	local element = event.element
	if not element or element.name ~= cs2.WINDOW_NAME then return end
	cs2.close_combinator_gui(event.player_index)
end)
