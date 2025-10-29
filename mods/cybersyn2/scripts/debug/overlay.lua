--------------------------------------------------------------------------------
-- Use `LuaRendering` to draw relevant debugging information on screen.
--------------------------------------------------------------------------------

local pos_lib = require("lib.core.math.pos")
local bbox_lib = require("lib.core.math.bbox")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

local Combinator = _G.cs2.Combinator

---@class Cybersyn.Internal.DebugOverlayState
---@field public comb_overlays {[UnitNumber]: LuaRenderObject}
---@field public stop_overlays {[UnitNumber]: Cybersyn.Internal.StopDebugOverlayState}
---@field public bbox_overlay LuaRenderObject?

---@class Cybersyn.Internal.StopDebugOverlayState
---@field public text Cybersyn.Internal.MultiLineTextOverlay
---@field public associations LuaRenderObject[]
---@field public bbox LuaRenderObject?

---@class Cybersyn.Internal.MultiLineTextOverlay
---@field public backdrop LuaRenderObject
---@field public text_lines LuaRenderObject[]
---@field public width number
---@field public line_height number

---@param objs LuaRenderObject[]?
local function destroy_render_objects(objs)
	if not objs then return end
	for _, obj in pairs(objs) do
		obj.destroy()
	end
end

---@param state Cybersyn.Internal.MultiLineTextOverlay
local function clear_text_overlay(state)
	if state.backdrop then state.backdrop.destroy() end
	destroy_render_objects(state.text_lines)
end

---@param surface LuaSurface
---@param lt_target ScriptRenderTargetTable
---@param width number Width of the text box.
---@param line_height number Height of each line of text.
---@return Cybersyn.Internal.MultiLineTextOverlay
local function create_text_overlay(surface, lt_target, width, line_height)
	local backdrop = rendering.draw_rectangle({
		left_top = lt_target,
		right_bottom = lt_target,
		filled = true,
		surface = surface,
		color = { r = 0, g = 0, b = 0, a = 0.75 },
		visible = false,
	})
	return {
		backdrop = backdrop,
		text_lines = {},
		width = width,
		line_height = line_height,
	}
end

---@param overlay Cybersyn.Internal.MultiLineTextOverlay
---@param lines string[]?
local function set_text_overlay_text(overlay, lines)
	if (not lines) or (#lines == 0) then
		overlay.backdrop.visible = false
		for _, line in pairs(overlay.text_lines) do
			line.visible = false
		end
		return
	end
	local base_target = overlay.backdrop.left_top --[[@as ScriptRenderTargetTable]]
	local base_offset_x, base_offset_y =
		pos_lib.pos_get(base_target.offset or { 0, 0 })
	overlay.backdrop.visible = true
	overlay.backdrop.right_bottom = {
		entity = base_target.entity,
		offset = {
			base_offset_x + overlay.width,
			base_offset_y + #lines * overlay.line_height,
		},
	}
	for i = 1, #lines do
		local line_ro = overlay.text_lines[i]
		if not line_ro then
			line_ro = rendering.draw_text({
				text = "",
				surface = overlay.backdrop.surface,
				target = {
					entity = base_target.entity,
					offset = {
						base_offset_x,
						base_offset_y + (i - 1) * overlay.line_height,
					},
				},
				color = { r = 1, g = 1, b = 1 },
				use_rich_text = true,
				alignment = "left",
			})
			line_ro.bring_to_front()
			overlay.text_lines[i] = line_ro
		end
		line_ro.text = lines[i]
		line_ro.visible = true
	end
	for i = #lines + 1, #overlay.text_lines do
		overlay.text_lines[i].visible = false
	end
end

---@param state Cybersyn.Internal.StopDebugOverlayState
local function clear_stop_overlay(state)
	clear_text_overlay(state.text)
	destroy_render_objects(state.associations)
	if state.bbox then state.bbox.destroy() end
end

---@param combinator Cybersyn.Combinator
local function destroy_combinator_overlay(combinator)
	local ovl_data = storage.debug_state.overlay
	if not ovl_data then return end
	local overlay = ovl_data.comb_overlays[combinator.id]
	if overlay then
		overlay.destroy()
		ovl_data.comb_overlays[combinator.id] = nil
	end
end

---@param stop Cybersyn.TrainStop
---@return Cybersyn.Internal.StopDebugOverlayState?
local function get_or_create_stop_overlay(stop)
	local ovl_data = storage.debug_state.overlay
	if not ovl_data then return end
	local overlay = ovl_data.stop_overlays[stop.id]
	if not overlay then
		if not stop:is_valid() then return end
		stop = stop --[[@as Cybersyn.TrainStop]]
		overlay = {
			text = create_text_overlay(
				stop.entity.surface,
				{ entity = stop.entity, offset = { -2, -3 } },
				4,
				0.6
			),
			associations = {},
		}
		ovl_data.stop_overlays[stop.id] = overlay
	end
	return overlay
end

---@param stop Cybersyn.Node
local function destroy_stop_overlay(stop)
	local ovl_data = storage.debug_state.overlay
	if not ovl_data then return end
	local overlay = ovl_data.stop_overlays[stop.id]
	if overlay then
		clear_stop_overlay(overlay)
		ovl_data.stop_overlays[stop.id] = nil
	end
end

---@param stop Cybersyn.TrainStop
local function update_stop_overlay(stop)
	if not stop:is_valid() then return end
	stop = stop --[[@as Cybersyn.TrainStop]]
	local overlay = get_or_create_stop_overlay(stop)
	if not overlay then return end
	local layout = stop:get_layout()
	if not layout then return end
	local inventory = stop:get_inventory()
	if not inventory then return end

	-- Text
	local lines = {
		table.concat({
			"[item=train-stop]",
			stop.id,
			stop.per_wagon_mode and "[item=cargo-wagon]" or "",
			"[item=steel-chest]",
			stop.inventory_id,
		}),
	}
	table.insert(lines, table.concat(layout.carriage_loading_pattern or {}))
	table.insert(lines, "Allowed Layouts:")
	if stop.allowed_layouts then
		for tl_id in pairs(stop.allowed_layouts) do
			local tlayout = storage.train_layouts[tl_id]
			-- Make train layout into icons
			if tlayout then
				table.insert(
					lines,
					table.concat(
						tlib.map(
							(tlayout.carriage_names or {}),
							function(name) return "[item=" .. name .. "]" end
						)
					)
				)
			end
		end
	else
		table.insert(lines, "ALL")
	end
	set_text_overlay_text(overlay.text, lines)

	-- Lines indicating assiated combinators
	local n_assoc = 0
	for comb_id in pairs(stop.combinator_set) do
		local comb = cs2.get_combinator(comb_id)
		if comb and comb.real_entity then
			n_assoc = n_assoc + 1
			local assoc = overlay.associations[n_assoc]
			if not assoc then
				assoc = rendering.draw_line({
					color = { r = 0, g = 1, b = 0.25, a = 0.25 },
					width = 2,
					surface = stop.entity.surface,
					from = stop.entity,
					to = stop.entity,
				})
				overlay.associations[n_assoc] = assoc
			end
			assoc.from = comb.real_entity
			assoc.to = stop.entity
		end
		-- Destroy any extra association lines
		for i = n_assoc + 1, #overlay.associations do
			overlay.associations[i].destroy()
			overlay.associations[i] = nil
		end
	end

	-- Rect indicating bounding box
	if layout.bbox then
		local l, t, r, b = bbox_lib.bbox_get(layout.bbox)
		if not overlay.bbox then
			overlay.bbox = rendering.draw_rectangle({
				surface = stop.entity.surface,
				left_top = { l, t },
				right_bottom = { r, b },
				color = { r = 100, g = 149, b = 237 },
				width = 2,
			})
		else
			overlay.bbox.left_top = { l, t }
			overlay.bbox.right_bottom = { r, b }
		end
	else
		if overlay.bbox then overlay.bbox.destroy() end
	end
end

local function create_stop_overlays()
	local ovl_data = storage.debug_state.overlay
	if not ovl_data then return end
	for _, stop in pairs(storage.nodes) do
		if stop.type == "stop" then
			update_stop_overlay(stop --[[@as Cybersyn.TrainStop]])
		end
	end
end

local function create_all_overlays() create_stop_overlays() end

local function clear_all_overlays()
	local ovl_data = storage.debug_state.overlay
	if not ovl_data then return end
	for _, ovl in pairs(ovl_data.comb_overlays or {}) do
		ovl.destroy()
	end
	for _, ovl in pairs(ovl_data.stop_overlays or {}) do
		clear_stop_overlay(ovl)
	end
	if ovl_data.bbox_overlay then ovl_data.bbox_overlay.destroy() end
	storage.debug_state.overlay = nil
end

local function enable_overlays()
	if not storage.debug_state.overlay then
		storage.debug_state.overlay = {
			comb_overlays = {},
			stop_overlays = {},
		}
		create_all_overlays()
	end
end

local function enable_or_disable_overlays()
	if mod_settings.debug then
		enable_overlays()
	else
		clear_all_overlays()
	end
end

events.bind("on_shutdown", clear_all_overlays)

cs2.on_mod_settings_changed(enable_or_disable_overlays)
cs2.on_combinator_destroyed(destroy_combinator_overlay)
--cs2.on_combinator_created(update_combinator_overlay)
cs2.on_combinator_node_associated(function(combinator, new_node, old_node)
	--update_combinator_overlay(combinator)
	-- if new_node then
	-- 	local l, t, r, b = mlib.bbox_get(combinator.entity.bounding_box)
	-- 	rendering.draw_rectangle({
	-- 		color = { r = 0, g = 1, b = 1, a = 0.5 },
	-- 		left_top = { l, t },
	-- 		right_bottom = { r, b },
	-- 		surface = combinator.entity.surface,
	-- 		time_to_live = 300,
	-- 	})
	-- end
end)
cs2.on_node_destroyed(destroy_stop_overlay)
cs2.on_node_created(update_stop_overlay)
cs2.on_node_combinator_set_changed(update_stop_overlay)
cs2.on_train_stop_layout_changed(update_stop_overlay)
cs2.on_train_stop_pattern_changed(update_stop_overlay)
cs2.on_node_data_changed(function(node)
	if node.type == "stop" then
		update_stop_overlay(node --[[@as Cybersyn.TrainStop]])
	end
end)
