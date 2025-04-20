-- Utilities relating to blueprints.

if ... ~= "__cybersyn2__.lib.blueprint" then
	return require("__cybersyn2__.lib.blueprint")
end

local mlib = require("__cybersyn2__.lib.math")

-- XXX: remove
local stlib = require("__cybersyn2__.lib.strace")
local strace = stlib.strace

local floor = math.floor
local ceil = math.ceil
local pos_get = mlib.pos_get
local pos_set = mlib.pos_set
local pos_new = mlib.pos_new
local pos_add = mlib.pos_add
local pos_rotate_ortho = mlib.pos_rotate_ortho
local bbox_new = mlib.bbox_new
local bbox_rotate_ortho = mlib.bbox_rotate_ortho
local bbox_translate = mlib.bbox_translate
local bbox_union = mlib.bbox_union
local bbox_get = mlib.bbox_get
local bbox_set = mlib.bbox_set
local bbox_round = mlib.bbox_round
local pos_set_center = mlib.pos_set_center
local bbox_flip_horiz = mlib.bbox_flip_horiz
local bbox_flip_vert = mlib.bbox_flip_vert
local rect_from_bbox = mlib.rect_from_bbox

local lib = {}

-- Helper function for coordinate snapping
local function snap(x, dx)
	if (ceil(dx) % 2) == 0 then
		return floor(x + 0.5)
	else
		-- Snap to center
		return floor(x) + 0.5
	end
end

---A blueprint-like object
---@alias BlueprintLib.Blueprintish LuaItemStack|LuaRecord

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
---@field public overlap? {[int]: LuaEntity} A mapping of the blueprint entity indices to the entities in the world that would be overlapped by the corresponding entities in the blueprint if it were pasted at that position in worldspace.
---@field public bpspace_bbox? BoundingBox The bounding box of the blueprint in blueprint space.
---@field public bp_to_bbox? {[int]: BoundingBox} A mapping of the blueprint entity indices to the bounding boxes of the entities in blueprint space.
---@field public bp_to_world_pos? {[int]: MapPosition} A mapping of the blueprint entity indices to positions in worldspace of where those entities will be when the blueprint is built.
---@field public snap? TilePosition Blueprint snapping grid size
---@field public snap_offset? TilePosition Blueprint snapping grid offset
---@field public snap_absolute? boolean Whether blueprint snapping is absolute or relative
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

---Given either a record or a stack, which might be a blueprint or a blueprint book,
---return the actual blueprint involved, stripped of any containing books.
---@param player LuaPlayer The player who is manipulating the blueprint.
---@param record? LuaRecord
---@param stack? LuaItemStack
---@return (LuaItemStack|LuaRecord)? blueprintish The actual blueprint involved, stripped of any containing books or nil if not found.
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
end

function BlueprintInfo:get_bpspace_bbox()
	if not self.bpspace_bbox then
		local bp_entities = self:get_entities()
		if not bp_entities or #bp_entities == 0 then return end
		local entity_bboxes = {}
		self.bp_to_bbox = entity_bboxes
		local zero = { 0, 0 }
		local e1x, e1y = pos_get(bp_entities[1].position)
		---@type BoundingBox
		local bpspace_bbox = { { e1x, e1y }, { e1x, e1y } }
		for i = 1, #bp_entities do
			local bp_entity = bp_entities[i]
			local eproto = prototypes.entity[bp_entity.name]
			-- If detecting a rail entity, we need to snap to nearest multiple of 2
			-- TODO: more comprehensive snapping, elel rails etc
			local eproto_type = eproto.type
			if
				eproto_type == "straight-rail"
				or eproto_type == "curved-rail-a"
				or eproto_type == "curved-rail-b"
				or eproto_type == "train-stop"
			then
				if not self.snap then self.snap = { 2, 2 } end
			end
			-- NOTE: this is an attempt to approximate whatever Factorio is doing
			-- when computing blueprint size.
			local ebox = bbox_new(eproto.collision_box)
			local dir = bp_entity.direction
			if dir and dir ~= 0 and dir % 4 == 0 then
				bbox_rotate_ortho(ebox, zero, floor(dir / 4))
			end
			bbox_translate(ebox, bp_entity.position)
			entity_bboxes[i] = ebox
			bbox_union(bpspace_bbox, ebox)
		end
		self.bpspace_bbox = bpspace_bbox
	end
	return self.bpspace_bbox
end

local function floor_grid_square(x, y, gx, gy, ox, oy)
	local left = floor((x - ox) / gx) * gx + ox
	local top = floor((y - oy) / gy) * gy + oy
	local right = left + gx
	local bottom = top + gy
	return left, top, right, bottom
end

local function nearest_grid_point(x, y, gx, gy, ox, oy)
	local nearest_x = floor((x - ox) / gx + 0.5) * gx + ox
	local nearest_y = floor((y - oy) / gy + 0.5) * gy + oy
	return nearest_x, nearest_y
end

local ONES = { 1, 1 }
local ZEROES = { 0, 0 }

---For a blueprint being built, get a map from the blueprint entity indices to
---the positions in worldspace of where those entities will be when the
---blueprint is built.
function BlueprintInfo:get_bp_to_world_pos()
	if self.bp_to_world_pos then return self.bp_to_world_pos end
	local bbox = self:get_bpspace_bbox()
	if not bbox then return end
	bbox = bbox_new(bbox)
	local l, t, r, b = bbox_get(bbox)

	local bpspace_center = { (l + r) / 2, (t + b) / 2 }

	-- Rotate by blueprint placement rotation
	local rotation, bp_rot_n = self.direction, 0
	if rotation % 4 == 0 then bp_rot_n = floor(rotation / 4) end
	-- bbox_rotate_ortho(bbox, bpspace_center, bp_rot_n)
	-- l, t, r, b = bbox_get(bbox)
	strace(
		stlib.DEBUG,
		"cs2",
		"blueprint",
		"message",
		"bbox",
		bbox,
		"dxy",
		r - l,
		b - t
	)

	-- Snap placement position to tile grid
	local snap_grid = self.snap
	local snap_offset = self.snap_offset
	local snap_absolute = self.snap_absolute
	-- strace(
	-- 	stlib.DEBUG,
	-- 	"cs2",
	-- 	"blueprint",
	-- 	"message",
	-- 	"blueprint snapping info",
	-- 	snap_grid,
	-- 	snap_offset,
	-- 	snap_absolute
	-- )

	-- Base coordinates
	local position = self.position --[[@as MapPosition]]
	local x, y = pos_get(position)
	local gx, gy = pos_get(self.snap or ONES)
	local ox, oy = pos_get(self.snap_offset or ZEROES)
	local translation_center = pos_new()
	-- XXX purple circle at mouse pos
	rendering.draw_circle({
		color = { r = 1, g = 0, b = 1, a = 0.75 },
		width = 1,
		filled = true,
		target = position,
		radius = 0.3,
		surface = self.surface,
		time_to_live = 1800,
	})

	-- Grid snapping
	local placement_bbox = bbox_new()
	if self.snap_absolute then
		-- When absolute snapping, the mouse cursor is snapped to a grid square
		-- first, then the BP topleft is made to match the topleft of that grid square.
		local gl, gt, gr, gb = floor_grid_square(x, y, gx, gy, ox, oy)
		local rot_center = { (gl + gr) / 2, (gt + gb) / 2 }
		bbox_set(placement_bbox, gl, gt, gl + (r - l), gt + (b - t))
		if self.flip_horizontal then
			bbox_flip_horiz(placement_bbox, rot_center[1])
		end
		if self.flip_vertical then bbox_flip_vert(placement_bbox, rot_center[2]) end
		bbox_rotate_ortho(placement_bbox, rot_center, -bp_rot_n)
		local pl, pt, pr, pb = bbox_get(placement_bbox)

		-- XXX: draw gridsquare
		rendering.draw_rectangle({
			color = { r = 0, g = 0, b = 1, a = 1 },
			width = 1,
			filled = false,
			left_top = { gl, gt },
			right_bottom = { gr, gb },
			surface = self.surface,
			time_to_live = 1800,
		})
		-- XXX: draw new bbox
		rendering.draw_rectangle({
			color = { r = 0, g = 1, b = 0, a = 1 },
			width = 1,
			filled = false,
			left_top = { pl, pt },
			right_bottom = { pr, pb },
			surface = self.surface,
			time_to_live = 1800,
		})
	else
		-- Relative snapping. Draw bbox as if it were centered on the mouse cursor,
		-- then bring its topleft to the nearest gridpoint.
		local dx, dy = (r - l) / 2, (b - t) / 2
		bbox_set(placement_bbox, x - dx, y - dy, x + dx, y + dy)
		if self.flip_horizontal then bbox_flip_horiz(placement_bbox, x) end
		if self.flip_vertical then bbox_flip_vert(placement_bbox, y) end
		bbox_rotate_ortho(placement_bbox, position, -bp_rot_n)
		local pl, pt, pr, pb = bbox_get(placement_bbox)
		dx, dy = pr - pl, pb - pt
		pl, pt = nearest_grid_point(pl, pt, gx, gy, ox, oy)
		bbox_set(placement_bbox, pl, pt, pl + dx, pt + dy)
		-- XXX: draw new bbox
		rendering.draw_rectangle({
			color = { r = 0, g = 1, b = 0, a = 1 },
			width = 1,
			filled = false,
			left_top = { pl, pt },
			right_bottom = { pr, pb },
			surface = self.surface,
			time_to_live = 1800,
		})
	end
	pos_set_center(translation_center, placement_bbox)

	-- Compute per-entity positions
	local bp_to_world_pos = {}
	local bp_entities = self:get_entities() --[[@as BlueprintEntity[] ]]
	for i = 1, #bp_entities do
		-- Get bpspace position
		local epos = pos_new(bp_entities[i].position)
		-- Move to central frame of reference
		pos_add(epos, -1, bpspace_center)
		-- Apply flip
		local rx, ry = pos_get(epos)
		if self.flip_horizontal then rx = -rx end
		if self.flip_vertical then ry = -ry end
		pos_set(epos, rx, ry)
		-- Apply blueprint rotation
		pos_rotate_ortho(epos, ZEROES, -bp_rot_n)
		-- Translate back to worldspace
		pos_add(epos, 1, translation_center)

		-- XXX
		rendering.draw_circle({
			color = { r = 1, g = 0, b = 0, a = 1 },
			width = 1,
			filled = true,
			target = epos,
			radius = 0.3,
			surface = self.surface,
			time_to_live = 1800,
		})

		-- XXX
		local ebox = bbox_new(self.bp_to_bbox[i])
		bbox_translate(ebox, -1 * bpspace_center[1], -1 * bpspace_center[2])
		bbox_translate(ebox, translation_center)
		local ebl, ebt, ebr, ebb = bbox_get(ebox)
		rendering.draw_rectangle({
			color = { r = 0, g = 0, b = 1, a = 1 },
			width = 1,
			filled = false,
			left_top = { ebl, ebt },
			right_bottom = { ebr, ebb },
			surface = self.surface,
			time_to_live = 1800,
		})

		bp_to_world_pos[i] = epos
	end

	self.bp_to_world_pos = bp_to_world_pos
	return bp_to_world_pos
end

---Given the entities in a blueprint, a worldspace location where it is being placed,
---and the rotation and flip state of the blueprint, find the pre-existing
---entites that would be overlapped by corresponding entities in the blueprint if it were pasted at that position in worldspace.
---The entities' prototype names must match to be considered overlapping.
---@param bp_entity_filter? fun(bp_entity: BlueprintEntity): boolean Filters which blueprint entities are considered for overlap. Filtering can save considerable work in handling large blueprints. (Note that you MUST NOT prefilter the blueprint entities array before calling this function.)
---@return table<uint, LuaEntity> map A table mapping the index of the blueprint entity to the overlapping entity in the world. Note that this is not a true array as indices not corresponding to overlapped entities will be nil.
function BlueprintInfo:get_overlap(bp_entity_filter)
	if self.overlap then return self.overlap end

	local bp_entities = self:get_entities()
	if (not bp_entities) or (#bp_entities == 0) then return {} end
	local surface = self.surface
	local position = self.position
	local rotation = self.direction
	local flip_horizontal = self.flip_horizontal
	local flip_vertical = self.flip_vertical

	-- Must first compute the center of blueprint space, as that will be translated
	-- to the given worldspace position.
	local e1x, e1y = pos_get(bp_entities[1].position)
	---@type BoundingBox
	local bpspace_bbox = { { e1x, e1y }, { e1x, e1y } }
	---@type table<uint, MapPosition>
	local entity_pos = {}
	---@type MapPosition
	local zero = { 0, 0 }
	for i = 1, #bp_entities do
		local bp_entity = bp_entities[i]
		local bp_entity_name = bp_entity.name
		local bp_entity_pos = bp_entity.position
		local ebox = bbox_new(prototypes.entity[bp_entity_name].selection_box)
		if (not bp_entity_filter) or bp_entity_filter(bp_entity) then
			entity_pos[i] = pos_new(bp_entity_pos)
		end
		local dir = bp_entity.direction
		if dir and dir % 4 == 0 then
			bbox_rotate_ortho(ebox, zero, floor(dir / 4))
		end
		bbox_translate(ebox, bp_entity_pos)
		bbox_union(bpspace_bbox, ebox)
	end
	-- Early out if no filtered entities are present.
	if not next(entity_pos) then return {} end

	-- Find center
	local l, t, r, b = bbox_get(bpspace_bbox)
	---@type MapPosition
	local bpspace_center = { (l + r) / 2, (t + b) / 2 }

	-- Rotate by blueprint placement rotation
	local bp_rot_n = 0
	if rotation % 4 == 0 then bp_rot_n = floor(rotation / 4) end
	bbox_rotate_ortho(bpspace_bbox, bpspace_center, bp_rot_n)
	l, t, r, b = bbox_get(bpspace_bbox)

	-- Snap placement position to tile grid
	local x, y = pos_get(position)
	local snapped_position = { snap(x, r - l), snap(y, b - t) }

	-- Apply translation, flip, and rotation to the positions of relevant
	-- entities.
	for _, epos in pairs(entity_pos) do
		pos_add(epos, -1, bpspace_center)
		local rx, ry = pos_get(epos)
		if flip_horizontal then rx = -rx end
		if flip_vertical then ry = -ry end
		pos_set(epos, rx, ry)
		pos_rotate_ortho(epos, zero, -bp_rot_n)

		-- Translate back to worldspace
		pos_add(epos, 1, snapped_position)
	end

	-- Finally, attempt to find entities at the computed positions with the
	-- same name as the blueprint entities.
	---@type table<uint, LuaEntity>
	local map = {}
	for i, epos in pairs(entity_pos) do
		local entity = surface.find_entity(bp_entities[i].name, epos)
		if entity then map[i] = entity end
	end

	self.overlap = map
	return map
end

return lib
