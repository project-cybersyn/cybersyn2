-- Library of math, point, and box manipulation functions.
-- Why not just use flib for this? Well, each flib math function creates
-- unnecessary Lua garbage. These functions attempt to operate purely on
-- the Lua stack and avoid creating temp tables as much as possible.

if ... ~= "__cybersyn2__.lib.math" then
	return require("__cybersyn2__.lib.math")
end

local abs = math.abs
local min = math.min
local max = math.max

local dir_N = defines.direction.north
local dir_S = defines.direction.south
local dir_E = defines.direction.east
local dir_W = defines.direction.west

local lib = {}

---Get the coordinates of a position.
---@param pos MapPosition
local function pos_get(pos)
	if pos.x then
		return pos.x, pos.y
	else
		return pos[1], pos[2]
	end
end
lib.pos_get = pos_get

---Set the coordinates of a position.
---@param pos MapPosition
---@param x number
---@param y number
local function pos_set(pos, x, y)
	if pos.x then
		pos.x, pos.y = x, y
	else
		pos[1], pos[2] = x, y
	end
	return pos
end
lib.pos_set = pos_set

---Create a new position, optionally cloning an existing one.
---@param pos MapPosition?
---@return MapPosition #The new position.
local function pos_new(pos)
	if pos then
		local x, y = pos_get(pos)
		return { x, y }
	else
		return { 0, 0 }
	end
end
lib.pos_new = pos_new

---Move a position by the given amount in the given ortho direction.
---@param pos MapPosition
---@param dir defines.direction
---@param amount number
---@return MapPosition pos The original position, modified as requested.
local function pos_move_ortho(pos, dir, amount)
	local x, y = pos_get(pos)
	if dir == dir_N then
		y = y - amount
	elseif dir == dir_S then
		y = y + amount
	elseif dir == dir_E then
		x = x + amount
	elseif dir == dir_W then
		x = x - amount
	end
	return pos_set(pos, x, y)
end
lib.pos_move_ortho = pos_move_ortho

---Returns the primary orthogonal direction from `pos1` to `pos2`. This is one of the
---`defines.direction` constants.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return defines.direction
local function dir_ortho(pos1, pos2)
	local x1, y1 = pos_get(pos1)
	local x2, y2 = pos_get(pos2)
	local dx, dy = x2 - x1, y2 - y1
	if abs(dx) > abs(dy) then
		return dx > 0 and dir_E or dir_W
	else
		return dy > 0 and dir_S or dir_N
	end
end
lib.dir_ortho = dir_ortho

---Rotate a position 90 degrees around an origin.
---The direction of rotation is clockwise if `clockwise` is true, otherwise
---counterclockwise. Mutates the given position
---@param pos MapPosition
---@param origin MapPosition
---@param clockwise boolean?
---@return MapPosition pos The mutated position.
local function pos_rotate_90(pos, origin, clockwise)
	local x, y = pos_get(pos)
	local ox, oy = pos_get(origin)
	local dx, dy = x - ox, y - oy
	if clockwise then
		return pos_set(pos, ox - dy, oy + dx)
	else
		return pos_set(pos, ox + dy, oy - dx)
	end
end
lib.pos_rotate_90 = pos_rotate_90

--- Get the four corners of any bbox.
---@param bbox BoundingBox
---@return number left
---@return number top
---@return number right
---@return number bottom
local function bbox_get(bbox)
	local lt, rb
	if bbox.left_top then
		lt, rb = bbox.left_top, bbox.right_bottom
	else
		lt, rb = bbox[1], bbox[2]
	end
	if lt.x then
		if rb.x then
			return lt.x, lt.y, rb.x, rb.y
		else
			return lt.x, lt.y, rb[1], rb[2]
		end
	else
		if rb.x then
			return lt[1], lt[2], rb.x, rb.y
		else
			return lt[1], lt[2], rb[1], rb[2]
		end
	end
end
lib.bbox_get = bbox_get

--- Mutate a bbox, setting its corners.
---@param bbox BoundingBox
---@param left number
---@param top number
---@param right number
---@param bottom number
---@return BoundingBox bbox The mutated bbox.
local function bbox_set(bbox, left, top, right, bottom)
	local lt, rb
	if bbox.left_top then
		lt, rb = bbox.left_top, bbox.right_bottom
	else
		lt, rb = bbox[1], bbox[2]
	end
	if lt.x then
		if rb.x then
			lt.x, lt.y, rb.x, rb.y = left, top, right, bottom
		else
			lt.x, lt.y, rb[1], rb[2] = left, top, right, bottom
		end
	else
		if rb.x then
			lt[1], lt[2], rb.x, rb.y = left, top, right, bottom
		else
			lt[1], lt[2], rb[1], rb[2] = left, top, right, bottom
		end
	end
	return bbox
end
lib.bbox_set = bbox_set

---Create a new bbox, optionally cloning an existing one. If not provided,
---the new bbox has all coordinate zeroed.
---@param bbox BoundingBox?
---@return BoundingBox #The new bbox.
local function bbox_new(bbox)
	if bbox then
		local l, t, r, b = bbox_get(bbox)
		return { { l, t }, { r, b } }
	else
		return { { 0, 0 }, { 0, 0 } }
	end
end
lib.bbox_new = bbox_new

---Normalize the points of a bbox, ensuring that the left is always less than
---the right, and the top is always less than the bottom.
---@param l number
---@param t number
---@param r number
---@param b number
local function bbox_normalize(l, t, r, b)
	if l > r then
		l, r = r, l
	end
	if t > b then
		t, b = b, t
	end
	return l, t, r, b
end
lib.bbox_normalize = bbox_normalize

---Extend a bbox to contain another bbox, mutating the first.
---@param bbox1 BoundingBox
---@param bbox2 BoundingBox
---@return BoundingBox bbox1 The first bbox, extended to contain the second.
local function bbox_union(bbox1, bbox2)
	local l1, t1, r1, b1 = bbox_get(bbox1)
	local l2, t2, r2, b2 = bbox_get(bbox2)
	return bbox_set(bbox1, min(l1, l2), min(t1, t2), max(r1, r2), max(b1, b2))
end
lib.bbox_union = bbox_union

---Grow a bbox by the given amount in the given ortho direction.
---@param bbox BoundingBox
---@param dir defines.direction
---@param amount number
---@return BoundingBox bbox The mutated bbox.
local function bbox_extend_ortho(bbox, dir, amount)
	local l, t, r, b = bbox_get(bbox)
	if dir == dir_N then
		t = t - amount
	elseif dir == dir_S then
		b = b + amount
	elseif dir == dir_E then
		r = r + amount
	elseif dir == dir_W then
		l = l - amount
	end
	return bbox_set(bbox, l, t, r, b)
end
lib.bbox_extend_ortho = bbox_extend_ortho

---Measure the distance of the given point along the given orthogonal axis
---of the given bounding box. The direction indicates the positive measurement
---axis, with the zero point of the axis being on the opposite side of the box.
---@param bbox BoundingBox
---@param direction defines.direction One of the four cardinal directions. Other directions will give invalid results.
---@param point MapPosition
---@return number distance The distance along the axis.
local function bbox_measure_ortho(bbox, direction, point)
	local l, t, r, b = bbox_get(bbox)
	local x, y = pos_get(point)
	if direction == dir_N then
		return b - y
	elseif direction == dir_S then
		return y - t
	elseif direction == dir_E then
		return x - l
	elseif direction == dir_W then
		return r - x
	else
		error("dist_ortho_bbox: Invalid direction")
	end
end
lib.bbox_measure_ortho = bbox_measure_ortho

---Rotate a bbox 90 degrees around an origin.
---The direction of rotation is clockwise if `clockwise` is true, otherwise
---counterclockwise. Mutates the given bbox.
---@param bbox BoundingBox
---@param origin MapPosition
---@param clockwise boolean?
---@return BoundingBox bbox The mutated bbox.
local function bbox_rotate_90(bbox, origin, clockwise)
	local l, t, r, b = bbox_get(bbox)
	local ox, oy = pos_get(origin)
	if clockwise then
		l, t, r, b = bbox_normalize(ox - b + oy, oy + l - ox, ox - t + oy, oy + r - ox)
		return bbox_set(bbox, l, t, r, b)
	else
		l, t, r, b = bbox_normalize(ox + t - oy, oy - l + ox, ox + b - oy, oy - r + ox)
		return bbox_set(bbox, l, t, r, b)
	end
end
lib.bbox_rotate_90 = bbox_rotate_90

---Translate a bbox by the given vector. Mutates the given bbox.
---@param bbox BoundingBox
---@param pos_or_dx MapPosition|number
---@param dy? number
local function bbox_translate(bbox, pos_or_dx, dy)
	local dx = 0
	if type(pos_or_dx) == "table" then
		dx, dy = pos_get(pos_or_dx)
	else
		dx = pos_or_dx --[[@as number]]
	end
	local l, t, r, b = bbox_get(bbox)
	return bbox_set(bbox, l + dx, t + dy, r + dx, b + dy)
end
lib.bbox_translate = bbox_translate

return lib
