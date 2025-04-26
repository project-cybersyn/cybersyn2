-- Utilities relating to blueprints.

if ... ~= "__cybersyn2__.lib.blueprint" then
	return require("__cybersyn2__.lib.blueprint")
end

local mlib = require("__cybersyn2__.lib.math")

local PI = math.pi
local floor = math.floor
local pos_get = mlib.pos_get
local pos_set = mlib.pos_set
local pos_new = mlib.pos_new
local pos_add = mlib.pos_add
local pos_rotate_ortho = mlib.pos_rotate_ortho
local bbox_new = mlib.bbox_new
local bbox_rotate_ortho = mlib.bbox_rotate_ortho
local bbox_translate = mlib.bbox_translate
local bbox_get = mlib.bbox_get
local bbox_set = mlib.bbox_set
local bbox_round = mlib.bbox_round
local pos_set_center = mlib.pos_set_center
local bbox_flip_horiz = mlib.bbox_flip_horiz
local bbox_flip_vert = mlib.bbox_flip_vert
local rect_from_bbox = mlib.rect_from_bbox
local rect_rotate = mlib.rect_rotate
local bbox_union_rect = mlib.bbox_union_rect
local rect_translate = mlib.rect_translate
local ZEROES = { 0, 0 }

local lib = {}

---A blueprint-like object
---@alias BlueprintLib.Blueprintish LuaItemStack|LuaRecord

---Given either a record or a stack, which might be a blueprint or a blueprint book,
---return the actual blueprint involved, stripped of any containing books.
---@param player LuaPlayer The player who is manipulating the blueprint.
---@param record? LuaRecord
---@param stack? LuaItemStack
---@return BlueprintLib.Blueprintish? blueprintish The actual blueprint involved, stripped of any containing books or nil if not found.
local function get_actual_blueprint(player, record, stack)
	-- Determine the actual blueprint being held is ridiculously difficult to do.
	-- h/t Xorimuth on factorio discord for this.
	if record then
		while record and record.type == "blueprint-book" do
			record = record.contents[record.get_active_index(player)]
		end
		if record and record.type == "blueprint" then return record end
	elseif stack then
		if not stack.valid_for_read then return end
		while stack and stack.is_blueprint_book do
			stack =
				stack.get_inventory(defines.inventory.item_main)[stack.active_index]
		end
		if stack and stack.is_blueprint then return stack end
	end
end
lib.get_actual_blueprint = get_actual_blueprint

--------------------------------------------------------------------------------
-- SINGLE-ENTITY BBOXES AND SNAPPING
-- The factorio documentation for computing bounding boxes is basically
-- completely false for rails, particularly curved rails. The following code
-- is an attempt to empirically reverse engineer the behavior of rails wrt
-- bounding boxes and snapping, while falling back on factorio api
-- information for most entities where they are reliable.
--------------------------------------------------------------------------------

---Possible types of cursor snapping during relative blueprint placement.
---@enum Blueprint.SnapType
local SnapType = {
	"GRID_POINT",
	"TILE",
	"EVEN_GRID_POINT",
	"EVEN_TILE",
	"ODD_GRID_POINT",
	"ODD_TILE",
	GRID_POINT = 1,
	TILE = 2,
	EVEN_GRID_POINT = 3,
	EVEN_TILE = 4,
	ODD_GRID_POINT = 5,
	ODD_TILE = 6,
}

---Empirical data for a single direction of a single rail type. Entries are:
---[1] = Left offset from rail position to rail bbox edge.
---[2] = Top offset from rail position to rail bbox edge.
---[3] = Right offset from rail position to rail bbox edge.
---[4] = Bottom offset from rail position to rail bbox edge.
---[5] = Required parity of X coord position of rail on world grid. (1=odd, 2=even)
---[6] = Required parity of Y coord of position of rail on world grid. (1=odd, 2=even)
---@alias Blueprint.RailData { [1]: int, [2]: int, [3]: int, [4]: int, [5]: int, [6]: int }

---Rail data associated with each valid direction of a given rail type
---@alias Blueprint.RailDataPerDirection {[uint]: Blueprint.RailData}

---@type Blueprint.RailDataPerDirection
local curved_rail_a_table = {
	[0] = { -2, -3, 1, 2, 1, 2 },
	[2] = { -1, -3, 2, 2, 1, 2 },
	[4] = { -2, -2, 3, 1, 2, 1 },
	[6] = { -2, -1, 3, 2, 2, 1 },
	[8] = { -1, -2, 2, 3, 1, 2 },
	[10] = { -2, -2, 1, 3, 1, 2 },
	[12] = { -3, -1, 2, 2, 2, 1 },
	[14] = { -3, -2, 2, 1, 2, 1 },
}

---@type Blueprint.RailDataPerDirection
local curved_rail_b_table = {
	[0] = { -3, -3, 2, 3, 1, 1 },
	[2] = { -2, -3, 3, 3, 1, 1 },
	[4] = { -3, -3, 3, 2, 1, 1 },
	[6] = { -3, -2, 3, 3, 1, 1 },
	[8] = { -2, -3, 3, 3, 1, 1 },
	[10] = { -3, -3, 2, 3, 1, 1 },
	[12] = { -3, -2, 3, 3, 1, 1 },
	[14] = { -3, -3, 3, 2, 1, 1 },
}

---@type Blueprint.RailDataPerDirection
local straight_rail_table = {
	[0] = { -1, -1, 1, 1, 1, 1 },
	[2] = { -2, -2, 2, 2, 2, 2 },
	[4] = { -1, -1, 1, 1, 1, 1 },
	[6] = { -2, -2, 2, 2, 2, 2 },
	[8] = { -1, -1, 1, 1, 1, 1 },
	[10] = { -2, -2, 2, 2, 2, 2 },
	[12] = { -1, -1, 1, 1, 1, 1 },
	[14] = { -2, -2, 2, 2, 2, 2 },
}

---@type Blueprint.RailDataPerDirection
local half_diagonal_rail_table = {
	[0] = { -2, -2, 2, 2, 1, 1 },
	[2] = { -2, -2, 2, 2, 1, 1 },
	[4] = { -2, -2, 2, 2, 1, 1 },
	[6] = { -2, -2, 2, 2, 1, 1 },
	[8] = { -2, -2, 2, 2, 1, 1 },
	[10] = { -2, -2, 2, 2, 1, 1 },
	[12] = { -2, -2, 2, 2, 1, 1 },
	[14] = { -2, -2, 2, 2, 1, 1 },
}

---@type Blueprint.RailDataPerDirection
local train_stop_table = {
	[0] = { -1, -1, 1, 1, 1, 1 },
	[4] = { -1, -1, 1, 1, 1, 1 },
	[8] = { -1, -1, 1, 1, 1, 1 },
	[12] = { -1, -1, 1, 1, 1, 1 },
}

---Use an empirical lookup table to generate bounding boxes for particular
---known entity types.
---@param table Blueprint.RailDataPerDirection
---@return fun(bp_entity: BlueprintEntity, eproto: LuaEntityPrototype): Rect
local function table_bbox_getter(table)
	---@param bp_entity BlueprintEntity
	---@return Rect
	return function(bp_entity)
		local dir = bp_entity.direction or 0
		local x, y = pos_get(bp_entity.position)
		local adjustments = table[dir]
		if not adjustments then adjustments = { 0, 0, 0, 0 } end
		local box = {
			{ x + adjustments[1], y + adjustments[2] },
			{ x + adjustments[3], y + adjustments[4] },
		}
		local erect = rect_from_bbox(box)
		return erect
	end
end

---Generically compute the bounding box of a blueprint entity in blueprint space.
---Works for all entities that obey the factorio docs.
---@param bp_entity BlueprintEntity
---@param eproto LuaEntityPrototype
---@return Rect
local function default_bbox(bp_entity, eproto)
	local erect = rect_from_bbox(eproto.collision_box)
	local dir = bp_entity.direction or 0
	rect_rotate(erect, ZEROES, dir * PI / 8)
	rect_translate(erect, bp_entity.position)
	return erect
end

local empirical_bbox_types = {
	["curved-rail-a"] = table_bbox_getter(curved_rail_a_table),
	["curved-rail-b"] = table_bbox_getter(curved_rail_b_table),
	["straight-rail"] = table_bbox_getter(straight_rail_table),
	["half-diagonal-rail"] = table_bbox_getter(half_diagonal_rail_table),
	["elevated-half-diagonal-rail"] = table_bbox_getter(half_diagonal_rail_table),
	["elevated-straight-rail"] = table_bbox_getter(straight_rail_table),
	["elevated-curved-rail-a"] = table_bbox_getter(curved_rail_a_table),
	["elevated-curved-rail-b"] = table_bbox_getter(curved_rail_b_table),
}

local snappable_types = {
	["straight-rail"] = straight_rail_table,
	["half-diagonal-rail"] = half_diagonal_rail_table,
	["curved-rail-a"] = curved_rail_a_table,
	["curved-rail-b"] = curved_rail_b_table,
	["elevated-straight-rail"] = straight_rail_table,
	["elevated-half-diagonal-rail"] = half_diagonal_rail_table,
	["elevated-curved-rail-a"] = curved_rail_a_table,
	["elevated-curved-rail-b"] = curved_rail_b_table,
	["train-stop"] = train_stop_table,
}

---Get the bounding box of a single blueprint entity in blueprint space.
---@param bp_entity BlueprintEntity
---@param eproto LuaEntityPrototype
---@return Rect
local function get_bp_entity_bbox(bp_entity, eproto)
	local bbox_getter = empirical_bbox_types[eproto.type]
	if bbox_getter then
		return bbox_getter(bp_entity, eproto)
	else
		return default_bbox(bp_entity, eproto)
	end
end

---Get the net bounding box of an entire set of BP entities. Also locates an
---entity within the blueprint that will cause implied snapping for relative
---placement, if any.
---@param bp_entities BlueprintEntity[] A *nonempty* set of blueprint entities.
---@param rects? Rect[] If provided, will be filled with the bounding boxes of each entity by index.
---@return BoundingBox bbox The bounding box of the blueprint in blueprint space
---@return uint? snap_index The index of the entity that causes implied snapping, if any.
local function get_bp_bbox(bp_entities, rects)
	local snap_index = nil

	local e1x, e1y = pos_get(bp_entities[1].position)
	---@type BoundingBox
	local bpspace_bbox = { { e1x, e1y }, { e1x, e1y } }

	for i = 1, #bp_entities do
		local bp_entity = bp_entities[i]
		local eproto = prototypes.entity[bp_entity.name]
		local eproto_type = eproto.type

		-- Detect entities which cause implied snapping of the blueprint.
		if snap_index == nil then
			local snap_info = snappable_types[eproto_type]
			if snap_info then snap_index = i end
		end

		-- Get bbox for entity and union it with existing bbox.
		local erect = get_bp_entity_bbox(bp_entity, eproto)
		if rects then rects[i] = erect end
		bbox_union_rect(bpspace_bbox, erect)
	end

	bbox_round(bpspace_bbox)

	return bpspace_bbox, snap_index
end

---Get information on how the cursor position needs to be snapped when placing
---a blueprint with relative positioning.
---@param bp_entities BlueprintEntity[]
---@param bbox BoundingBox As computed previously by `get_bp_bbox`
---@param snap_index uint? As computed previously by `get_bp_bbox`
---@return Blueprint.SnapType xsnap Snapping type for the X-axis.
---@return Blueprint.SnapType ysnap Snapping type for the Y-axis.
local function get_bp_relative_snapping(bp_entities, bbox, snap_index)
	local l, t, r, b = bbox_get(bbox)
	local w, h = r - l, b - t
	local xsnap, ysnap = SnapType.GRID_POINT, SnapType.GRID_POINT
	if not snap_index then
		-- Simple snapping to tile or grid point.
		if floor(w) % 2 ~= 0 then xsnap = SnapType.TILE end
		if floor(h) % 2 ~= 0 then ysnap = SnapType.TILE end
		return xsnap, ysnap
	end

	-- Find snap entity
	local snap_entity = bp_entities[snap_index]
	local proto = prototypes.entity[snap_entity.name]
	local snap_entity_type = proto.type
	local snap_table =
		snappable_types[snap_entity_type][snap_entity.direction or 0]
	local snap_target_parity = { snap_table[5], snap_table[6] }

	-- Compute number of half integer steps from origin to controlling snap
	-- entity pos.
	local cx, cy = (l + r) / 2, (t + b) / 2
	local spos = pos_new(snap_entity.position)
	pos_add(spos, -1, { cx, cy })
	spos[1] = mlib.round(spos[1] / 0.5, 1)
	spos[2] = mlib.round(spos[2] / 0.5, 1)

	-- Find center parity that yields desired parity at snap entity position.
	-- X snapping
	if floor(w) % 2 == 0 then
		-- Center will be on grid point, meaning we are SnapType 1,3,5
		if snap_target_parity[1] == 1 then
			-- Target parity is odd. If we are a multiple of 4 halfsteps away,
			-- our parity must also be odd.
			if spos[1] % 4 == 0 then
				xsnap = SnapType.ODD_GRID_POINT
			else
				xsnap = SnapType.EVEN_GRID_POINT
			end
		else
			if spos[1] % 4 == 0 then
				xsnap = SnapType.EVEN_GRID_POINT
			else
				xsnap = SnapType.ODD_GRID_POINT
			end
		end
	else
		-- Center will be between grid points, meaning we are SnapType 2,4,6
		if snap_target_parity[1] == 1 then
			-- Target parity is odd.
			if spos[1] % 4 == 1 then
				-- Center of an even tile shifted by 1 half step
				-- gives an odd grid point.
				xsnap = SnapType.EVEN_TILE
			else
				xsnap = SnapType.ODD_TILE
			end
		else
			if spos[1] % 4 == 1 then
				xsnap = SnapType.ODD_TILE
			else
				xsnap = SnapType.EVEN_TILE
			end
		end
	end
	-- Y snapping
	if floor(h) % 2 == 0 then
		-- Center will be on grid point, meaning we are SnapType 1,3,5
		if snap_target_parity[2] == 1 then
			-- Target parity is odd. If we are a multiple of 4 halfsteps away,
			-- our parity must also be odd.
			if spos[2] % 4 == 0 then
				ysnap = SnapType.ODD_GRID_POINT
			else
				ysnap = SnapType.EVEN_GRID_POINT
			end
		else
			if spos[2] % 4 == 0 then
				ysnap = SnapType.EVEN_GRID_POINT
			else
				ysnap = SnapType.ODD_GRID_POINT
			end
		end
	else
		-- Center will be between grid points, meaning we are SnapType 2,4,6
		if snap_target_parity[2] == 1 then
			-- Target parity is odd.
			if spos[2] % 4 == 1 then
				ysnap = SnapType.EVEN_TILE
			else
				ysnap = SnapType.ODD_TILE
			end
		else
			if spos[2] % 4 == 1 then
				ysnap = SnapType.ODD_TILE
			else
				ysnap = SnapType.EVEN_TILE
			end
		end
	end
	return xsnap, ysnap
end

---Snap a coordinate to the appropriate grid point or tile based on the
---snap type.
---@param coord number
---@param snap_type Blueprint.SnapType
---@return number
local function snap_to(coord, snap_type)
	if snap_type == SnapType.GRID_POINT then
		return floor(coord + 0.5)
	elseif snap_type == SnapType.TILE then
		return floor(coord) + 0.5
	elseif snap_type == SnapType.EVEN_GRID_POINT then
		local snapped = floor(coord)
		if snapped % 2 ~= 0 then snapped = snapped + 1 end
		return snapped
	elseif snap_type == SnapType.EVEN_TILE then
		local snapped = floor(coord)
		if snapped % 2 ~= 0 then snapped = snapped + 1 end
		return snapped + 0.5
	elseif snap_type == SnapType.ODD_GRID_POINT then
		local snapped = floor(coord)
		if snapped % 2 == 0 then snapped = snapped + 1 end
		return snapped
	elseif snap_type == SnapType.ODD_TILE then
		local snapped = floor(coord)
		if snapped % 2 == 0 then snapped = snapped + 1 end
		return snapped + 0.5
	end

	return coord -- no snapping applied.
end

---In an absolute grid with squares sized `gx`x`gy` and a global offset of
---`(ox, oy)`, find the square containing the point `(x, y)` and return its
---bounding box.
---@param x number
---@param y number
---@param gx number Horizontal grid size
---@param gy number Vertical grid size
---@param ox number Horizontal grid offset
---@param oy number Vertical grid offset
local function get_absolute_grid_square(x, y, gx, gy, ox, oy)
	local left = floor((x - ox) / gx) * gx + ox
	local top = floor((y - oy) / gy) * gy + oy
	local right = left + gx
	local bottom = top + gy
	return left, top, right, bottom
end

---If the blueprint were stamped in the world with the given parameters,
---determine the resulting world position of each entity of the blueprint.
---@param bp_entities BlueprintEntity[] A *nonempty* set of blueprint entities
---@param bp_entity_filter? fun(bp_entity: BlueprintEntity): boolean Filters which blueprint entities will have their positions computed. Filtering can save some work in handling large blueprints. (Note that you MUST NOT prefilter the blueprint entities array before calling this function.)
---@param bbox BoundingBox As computed by `get_bp_bbox`.
---@param snap_index uint? As computed by `get_bp_bbox`.
---@param position MapPosition Placement position of the blueprint in worldspace.
---@param direction defines.direction Placement direction of the blueprint.
---@param flip_horizontal boolean? Whether the blueprint is flipped horizontally.
---@param flip_vertical boolean? Whether the blueprint is flipped vertically.
---@param snap TilePosition? If given, the size of the absolute grid to snap to.
---@param snap_offset TilePosition? If given, offset from the absolute grid.
---@param debug_render_surface LuaSurface? If given, debug graphics will be drawn on the given surface showing blueprint placement computations.
---@return {[uint]: MapPosition} bp_to_world_pos A mapping of blueprint entity indices to world positions.
local function get_bp_world_positions(
	bp_entities,
	bp_entity_filter,
	bbox,
	snap_index,
	position,
	direction,
	flip_horizontal,
	flip_vertical,
	snap,
	snap_offset,
	debug_render_surface
)
	local l, t, r, b = bbox_get(bbox)
	local bp_center = { (l + r) / 2, (t + b) / 2 }

	-- Round blueprint rotation to 90 deg increments.
	local rotation, bp_rot_n = direction, 0
	if rotation % 4 == 0 then bp_rot_n = floor(rotation / 4) end

	-- Base coordinates
	local x, y = pos_get(position)
	local translation_center = pos_new()
	if debug_render_surface then
		-- Debug: draw purple circle at mouse pos
		rendering.draw_circle({
			color = { r = 1, g = 0, b = 1, a = 0.75 },
			width = 1,
			filled = true,
			target = position,
			radius = 0.3,
			surface = debug_render_surface,
			time_to_live = 1800,
		})
	end

	-- Grid snapping
	local placement_bbox = bbox_new(bbox)
	if snap then
		-- Absolute snapping case
		-- When absolute snapping, the mouse cursor is snapped to a grid square
		-- first, then the zero of BP space is made to match the topleft of that grid square.
		local gx, gy = pos_get(snap)
		local ox, oy = pos_get(snap_offset or ZEROES)
		local gl, gt, gr, gb = get_absolute_grid_square(x, y, gx, gy, ox, oy)
		local rot_center = { (gl + gr) / 2, (gt + gb) / 2 }
		bbox_set(placement_bbox, l + gl, t + gt, r + gl, b + gt)

		-- In absolute snapping, rotation is about the center of the gridsquare.
		if flip_horizontal then bbox_flip_horiz(placement_bbox, rot_center[1]) end
		if flip_vertical then bbox_flip_vert(placement_bbox, rot_center[2]) end
		bbox_rotate_ortho(placement_bbox, rot_center, -bp_rot_n)
		local pl, pt, pr, pb = bbox_get(placement_bbox)

		if debug_render_surface then
			-- Debug: draw green box around computed absolute gridsquare
			rendering.draw_rectangle({
				color = { r = 0, g = 1, b = 0, a = 1 },
				width = 1,
				filled = false,
				left_top = { gl, gt },
				right_bottom = { gr, gb },
				surface = debug_render_surface,
				time_to_live = 1800,
			})
			-- Debug: draw blue box around worldspace bbox
			rendering.draw_rectangle({
				color = { r = 0, g = 0, b = 1, a = 1 },
				width = 1,
				filled = false,
				left_top = { pl, pt },
				right_bottom = { pr, pb },
				surface = debug_render_surface,
				time_to_live = 1800,
			})
		end
	else
		-- Relative snapping case.
		local xst, yst = get_bp_relative_snapping(bp_entities, bbox, snap_index)
		-- If rotating an odd direction, interchange x and y snapping
		if bp_rot_n % 2 == 1 then
			xst, yst = yst, xst
		end
		local sx, sy = snap_to(x, xst), snap_to(y, yst)
		if debug_render_surface then
			-- Debug: blue circle at snap point
			rendering.draw_circle({
				color = { r = 0, g = 0, b = 1, a = 0.75 },
				width = 1,
				filled = true,
				target = { sx, sy },
				radius = 0.3,
				surface = debug_render_surface,
				time_to_live = 1800,
			})
		end

		-- Compute bbox center
		local cx, cy = (l + r) / 2, (t + b) / 2
		-- Enact flip/rot
		if flip_horizontal then bbox_flip_horiz(placement_bbox, cx) end
		if flip_vertical then bbox_flip_vert(placement_bbox, cy) end
		bbox_rotate_ortho(placement_bbox, { cx, cy }, -bp_rot_n)
		-- Map center of bbox to snapped x,y
		bbox_translate(placement_bbox, 1, sx - cx, sy - cy)

		if debug_render_surface then
			-- Debug: draw world bbox in blue
			local pl, pt, pr, pb = bbox_get(placement_bbox)
			rendering.draw_rectangle({
				color = { r = 0, g = 0, b = 1, a = 1 },
				width = 1,
				filled = false,
				left_top = { pl, pt },
				right_bottom = { pr, pb },
				surface = debug_render_surface,
				time_to_live = 1800,
			})
		end
	end
	pos_set_center(translation_center, placement_bbox)

	-- Compute per-entity positions
	local bp_to_world_pos = {}
	for i = 1, #bp_entities do
		local bp_entity = bp_entities[i]
		if bp_entity_filter and not bp_entity_filter(bp_entity) then
			goto continue
		end
		-- Get bpspace position
		local epos = pos_new(bp_entity.position)
		-- Move to central frame of reference
		pos_add(epos, -1, bp_center)
		-- Apply flip
		local rx, ry = pos_get(epos)
		if flip_horizontal then rx = -rx end
		if flip_vertical then ry = -ry end
		pos_set(epos, rx, ry)
		-- Apply blueprint rotation
		pos_rotate_ortho(epos, ZEROES, -bp_rot_n)
		-- Translate back to worldspace
		pos_add(epos, 1, translation_center)

		if debug_render_surface then
			-- Debug: blue square at computed entity pos.
			-- This should overlap precisely with the green square drawn by the F4
			-- debug mode when showing entity positions.
			rendering.draw_rectangle({
				color = { r = 0, g = 0, b = 1, a = 1 },
				width = 1,
				filled = true,
				left_top = { epos[1] - 0.2, epos[2] - 0.2 },
				right_bottom = { epos[1] + 0.2, epos[2] + 0.2 },
				surface = debug_render_surface,
				time_to_live = 1800,
			})
		end

		-- XXX: draw rect
		-- local erect = rect_new(self.bp_to_rect[i])
		-- rect_translate(erect, bp_center, -1)
		-- rect_translate(erect, translation_center, 1)
		-- rendering.draw_line({
		-- 	color = { r = 0, g = 0, b = 1, a = 1 },
		-- 	width = 1,
		-- 	from = erect[1],
		-- 	to = erect[2],
		-- 	surface = self.surface,
		-- 	time_to_live = 1800,
		-- })
		-- rendering.draw_line({
		-- 	color = { r = 0, g = 0, b = 1, a = 1 },
		-- 	width = 1,
		-- 	from = erect[2],
		-- 	to = erect[3],
		-- 	surface = self.surface,
		-- 	time_to_live = 1800,
		-- })
		-- rendering.draw_line({
		-- 	color = { r = 0, g = 0, b = 1, a = 1 },
		-- 	width = 1,
		-- 	from = erect[3],
		-- 	to = erect[4],
		-- 	surface = self.surface,
		-- 	time_to_live = 1800,
		-- })
		-- rendering.draw_line({
		-- 	color = { r = 0, g = 0, b = 1, a = 1 },
		-- 	width = 1,
		-- 	from = erect[4],
		-- 	to = erect[1],
		-- 	surface = self.surface,
		-- 	time_to_live = 1800,
		-- })

		bp_to_world_pos[i] = epos
		::continue::
	end

	return bp_to_world_pos
end

--------------------------------------------------------------------------------
-- BLUEPRINTINFO TYPE
--------------------------------------------------------------------------------

---Class for end-to-end manipulation of blueprints. Lazily caches information
---about the blueprint and its entities as necessary.
---@class BlueprintLib.BlueprintInfo
---@field public record? LuaRecord The base record being manipulated if any
---@field public stack? LuaItemStack The base item stack being manipulated if any
---@field public player LuaPlayer The player who is manipulating the blueprint.
---@field public actual? BlueprintLib.Blueprintish The actual blueprint involved, stripped of any containing books.
---@field public entities? BlueprintEntity[] The entities in the blueprint.
---@field public lazy_bp_to_world? LuaLazyLoadedValue<{[int]: LuaEntity}> A lazy mapping of the blueprint entities to the entities in the world.
---@field public bp_to_world? {[int]: LuaEntity} A mapping of the blueprint entity indices to the entities in the world.
---@field public world_to_bp? {[UnitNumber]: int} A mapping from world entity unit numbers to blueprint entity indices.
---@field public surface? LuaSurface The surface where the blueprint is being placed.
---@field public position? MapPosition The worldspace position where the blueprint is being placed.
---@field public direction? defines.direction The rotation of the blueprint expressed as a Factorio direction.
---@field public flip_horizontal? boolean Whether the blueprint is flipped horizontally.
---@field public flip_vertical? boolean Whether the blueprint is flipped vertically.
---@field public bpspace_bbox? BoundingBox The bounding box of the blueprint in blueprint space.
---@field public bp_to_rect? {[int]: Rect} A mapping of the blueprint entity indices to the bounding rects of the entities in blueprint space.
---@field public bp_to_world_pos? {[int]: MapPosition} A mapping of the blueprint entity indices to positions in worldspace of where those entities will be when the blueprint is built.
---@field public snap? TilePosition Blueprint snapping grid size
---@field public snap_offset? TilePosition Blueprint snapping grid offset
---@field public snap_absolute? boolean Whether blueprint snapping is absolute or relative
---@field public debug? boolean Whether to draw debug graphics for the blueprint placement.
local BlueprintInfo = {}
BlueprintInfo.__index = BlueprintInfo
lib.BlueprintInfo = BlueprintInfo

---@param setup_event EventData.on_player_setup_blueprint
function BlueprintInfo:create_from_setup_event(setup_event)
	local player = game.get_player(setup_event.player_index)
	if not player then return nil end
	local obj = setmetatable({
		record = setup_event.record,
		stack = setup_event.stack,
		player = player,
		lazy_bp_to_world = setup_event.mapping,
	}, self)

	return obj
end

---@param event EventData.on_pre_build
function BlueprintInfo:create_from_pre_build_event(event)
	local player = game.get_player(event.player_index)
	if not player or not player.is_cursor_blueprint() then return nil end
	local obj = setmetatable({
		record = player.cursor_record,
		stack = player.cursor_stack,
		player = player,
		surface = player.surface,
		position = event.position,
		direction = event.direction,
		flip_horizontal = event.flip_horizontal,
		flip_vertical = event.flip_vertical,
	}, self)

	return obj
end

---Gets the actual blueprint being manipulated, stripped of containing books.
function BlueprintInfo:get_actual()
	if not self.actual then
		self.actual = get_actual_blueprint(self.player, self.record, self.stack)
		if self.actual then
			self.snap = self.actual.blueprint_snap_to_grid
			self.snap_offset = self.actual.blueprint_position_relative_to_grid
			self.snap_absolute = self.actual.blueprint_absolute_snapping
		end
	end
	return self.actual
end

---Get the pickled entities from the blueprint
---@param force boolean? If `true`, forcibly refetches from the api even if cached.
function BlueprintInfo:get_entities(force)
	if force or not self.entities then
		local actual = self:get_actual()
		if not actual then return end
		self.entities = actual.get_blueprint_entities()
	end
	return self.entities
end

---Retrieve a map from blueprint entity indices to the real-world entities
---that are being blueprinted. Only valid when a blueprint is being setup.
function BlueprintInfo:get_bp_to_world()
	if not self.bp_to_world then
		if not self.lazy_bp_to_world or not self.lazy_bp_to_world.valid then
			return
		end
		self.bp_to_world = self.lazy_bp_to_world.get() --[[@as table<uint, LuaEntity>]]
	end
	return self.bp_to_world
end

function BlueprintInfo:get_world_to_bp()
	if not self.world_to_bp then
		local bp_to_world = self:get_bp_to_world()
		if not bp_to_world then return end
		self.world_to_bp = {}
		for i, entity in pairs(bp_to_world) do
			local unum = entity.unit_number
			if unum then self.world_to_bp[unum] = i end
		end
	end
	return self.world_to_bp
end

---@param bp_entity_index uint
---@param tags Tags
function BlueprintInfo:apply_tags(bp_entity_index, tags)
	local actual = self:get_actual()
	if not actual then return end
	local old_tags = actual.get_blueprint_entity_tags(bp_entity_index)
	if not old_tags or (table_size(old_tags) == 0) then
		actual.set_blueprint_entity_tags(bp_entity_index, tags)
	else
		for k, v in pairs(tags) do
			old_tags[k] = v
		end
		actual.set_blueprint_entity_tags(bp_entity_index, old_tags)
	end
end

---@param bp_entity_index integer
---@param key string
---@param value AnyBasic
function BlueprintInfo:apply_tag(bp_entity_index, key, value)
	local actual = self:get_actual()
	if not actual then return end
	actual.set_blueprint_entity_tag(bp_entity_index, key, value)
end

---@param bp_entities BlueprintEntity[]
function BlueprintInfo:set_entities(bp_entities)
	local actual = self:get_actual()
	if not actual then return end
	actual.set_blueprint_entities(bp_entities)
	self.entities = bp_entities
	self.bpspace_bbox = nil
	self.bp_to_world_pos = nil
end

function BlueprintInfo:get_bpspace_bbox()
	if not self.bpspace_bbox then
		local bp_entities = self:get_entities()
		if not bp_entities or #bp_entities == 0 then return end

		local rects = {} -- XXX
		self.bp_to_rect = rects
		local bbox, snap_index = get_bp_bbox(bp_entities, rects)
		self.bpspace_bbox = bbox
		self.snap_index = snap_index
	end
	return self.bpspace_bbox
end

---For a blueprint being built, get a map from the blueprint entity indices to
---the positions in worldspace of where those entities will be when the
---blueprint is built.
function BlueprintInfo:get_bp_to_world_pos()
	if self.bp_to_world_pos then return self.bp_to_world_pos end
	local bbox = self:get_bpspace_bbox()
	if not bbox then return end
	local bp_entities = self:get_entities() --[[@as BlueprintEntity[] ]]

	local bp_to_world_pos = get_bp_world_positions(
		bp_entities,
		nil,
		bbox,
		self.snap_index,
		self.position,
		self.direction,
		self.flip_horizontal,
		self.flip_vertical,
		self.snap_absolute and self.snap or nil,
		self.snap_offset,
		self.debug and self.surface or nil
	)

	self.bp_to_world_pos = bp_to_world_pos
	return bp_to_world_pos
end

---Obtain a map from blueprint entity indices to the entities in the world
---that would be overlapped by the corresponding blueprint entity when it
---is placed.
---@param entity_filter fun(bp_entity: BlueprintEntity): boolean? Optional filter function to apply to the blueprint entities before checking for overlap.
---@return {[int]: LuaEntity}? overlap The overlapping entities indexed by the blueprint entity index that will overlap it.
function BlueprintInfo:get_overlap(entity_filter)
	local bpwp = self:get_bp_to_world_pos()
	if not bpwp then return end
	local bp_entities = self:get_entities() --[[@as BlueprintEntity[] ]]
	local surface = self.surface --[[@as LuaSurface]]

	local overlap = {}
	for index, pos in pairs(bpwp) do
		local bp_entity = bp_entities[index]
		if entity_filter and not entity_filter(bp_entity) then goto continue end
		local world_entity = surface.find_entity(bp_entity.name, pos)
		if world_entity then overlap[index] = world_entity end
		::continue::
	end
	return overlap
end

return lib
