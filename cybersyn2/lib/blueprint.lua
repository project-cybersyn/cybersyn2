-- Utilities relating to blueprints.

if ... ~= "__cybersyn2__.lib.blueprint" then
	return require("__cybersyn2__.lib.blueprint")
end

local mlib = require("__cybersyn2__.lib.math")

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

---Given either a record or a stack, which might be a blueprint or a blueprint book,
---return the actual blueprint involved, stripped of any containing books.
---@param player LuaPlayer The player who is manipulating the blueprint.
---@param record? LuaRecord
---@param stack? LuaItemStack
---@return (LuaItemStack|LuaRecord)? blueprintish The actual blueprint involved, stripped of any containing books or nil if not found.
function lib.get_actual_blueprint(player, record, stack)
	-- Determine the actual blueprint being held is ridiculously difficult to do.
	-- h/t Xorimuth on factorio discord for this.
	if record then
		while record and record.type == "blueprint-book" do
			record = record.contents[record.get_active_index(player)]
		end
		if record and record.type == "blueprint" then
			return record
		end
	elseif stack then
		if not stack.valid_for_read then return end
		while stack and stack.is_blueprint_book do
			stack = stack.get_inventory(defines.inventory.item_main)[stack.active_index]
		end
		if stack and stack.is_blueprint then
			return stack
		end
	end
end

---Given the entities in a blueprint, a worldspace location where it is being placed,
---and the rotation and flip state of the blueprint, find the pre-existing
---entites that would be overlapped by corresponding entities in the blueprint if it were pasted at that position in worldspace.
---The entities' prototype names must match to be considered overlapping.
---@param bp_entities? BlueprintEntity[] The entities in the blueprint.
---@param surface LuaSurface The surface where the blueprint is being placed.
---@param position MapPosition The worldspace position where the blueprint is being placed.
---@param rotation defines.direction The rotation of the blueprint expressed as a Factorio direction.
---@param flip_horizontal boolean Whether the blueprint is flipped horizontally.
---@param flip_vertical boolean Whether the blueprint is flipped vertically.
---@param bp_entity_filter? fun(bp_entity: BlueprintEntity): boolean Filters which blueprint entities are considered for overlap. Filtering can save considerable work in handling large blueprints. (Note that you MUST NOT prefilter the blueprint entities array before calling this function.)
---@return table<uint, LuaEntity> map A table mapping the index of the blueprint entity to the overlapping entity in the world. Note that this is not a true array as indices not corresponding to overlapped entities will be nil.
function lib.get_overlapping_entities(
		bp_entities,
		surface,
		position,
		rotation,
		flip_horizontal,
		flip_vertical,
		bp_entity_filter)
	if (not bp_entities) or (#bp_entities == 0) then return {} end

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
	if rotation % 4 == 0 then
		bp_rot_n = floor(rotation / 4)
	end
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

	return map
end

return lib
