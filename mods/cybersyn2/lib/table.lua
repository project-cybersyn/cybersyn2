-- Table and array functions

if ... ~= "__cybersyn2__.lib.table" then
	return require("__cybersyn2__.lib.table")
end

local lib = {}

local type = _G.type
local pairs = _G.pairs
local select = _G.select
local random = math.random

---An empty table enforced via metamethod.
local empty = setmetatable({}, { __newindex = function() end })
lib.empty = empty

---Shallowly compare two arrays using `==`
---@param A any[]
---@param B any[]
---@return boolean
function lib.a_eqeq(A, B)
	if #A ~= #B then return false end
	for i = 1, #A do
		if A[i] ~= B[i] then return false end
	end
	return true
end

---Recursively copy the contents of a table into a new table.
---@generic T
---@param tbl T The table to make a copy of.
---@param ignore_metatables boolean? If true, ignores metatables while copying.
---@return T
function lib.deep_copy(tbl, ignore_metatables)
	local lookup_table = {}
	local function _copy(_tbl)
		if type(_tbl) ~= "table" then
			return _tbl
		elseif lookup_table[_tbl] then
			return lookup_table[_tbl]
		end
		local new_table = {}
		lookup_table[_tbl] = new_table
		for index, value in pairs(_tbl) do
			new_table[_copy(index)] = _copy(value)
		end
		if ignore_metatables then
			return new_table
		else
			return setmetatable(new_table, getmetatable(_tbl))
		end
	end
	return _copy(tbl)
end

---Shallowly copies `src` into `dest`, returning `dest`.
---@generic K, V
---@param dest table<K, V>
---@param src table<K, V>?
---@return table<K, V>
local function assign(dest, src)
	if not src then return dest end
	for k, v in pairs(src) do
		dest[k] = v
	end
	return dest
end
lib.assign = assign

---@generic T
---@param t T
---@return T
function lib.shallow_copy(t) return assign({}, t) end

---Concatenate all input arrays into a single new result array
---@generic T
---@param ... T[][]
---@return T[]
function lib.concat(...)
	local A = {}
	for i = 1, select("#", ...) do
		local B = select(i, ...)
		for j = 1, #B do
			A[#A + 1] = B[j]
		end
	end
	return A
end

---Appends all non-`nil` args to the array `A`, returning `A`
---@generic T
---@param A T[]
---@param ... T?
---@return T[]
function lib.append(A, ...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if value ~= nil then A[#A + 1] = value end
	end
	return A
end

---Filter an array by a predicate function.
---@generic T
---@param A T[]
---@param f fun(value: T, index: integer): boolean
---@return T[] #A new array containing all elements of `A` for which the predicate returned true.
local function filter(A, f)
	local B = {}
	for i = 1, #A do
		if f(A[i], i) then B[#B + 1] = A[i] end
	end
	return B
end
lib.filter = filter

---Map an array to an array. Non-nil results of the mapping function
---will be collected into a new result array.
---@generic I, O
---@param A I[]
---@param f fun(value: I, index: integer): O?
---@return O[]
function lib.map(A, f)
	local B = {}
	for i = 1, #A do
		local x = f(A[i], i)
		if x ~= nil then B[#B + 1] = x end
	end
	return B
end

---Map a numeric for loop into an array via a mapping function.
---@generic T
---@param min integer
---@param max integer
---@param step integer
---@param f fun(i: integer): T
---@return T[]
function lib.map_range(min, max, step, f)
	local A = {}
	for i = min, max, step do
		A[#A + 1] = f(i)
	end
	return A
end

---Run a function for each element in a table.
---@generic K, V
---@param T table<K, V>
---@param f fun(value: V, key: K)
function lib.for_each(T, f)
	for k, v in pairs(T) do
		f(v, k)
	end
end

---Find the first entry in a table matching the given predicate.
---@generic K, V
---@param T table<K, V>
---@param f fun(value: V, key: K): boolean?
---@return V? value The value of the first matching entry, or `nil` if none was found
---@return K? key The key of the first matching entry, or `nil` if none was found
function lib.find(T, f)
	for k, v in pairs(T) do
		if f(v, k) then return v, k end
	end
end

---Map a table into an array. Non-nil results of the mapping function
---will be collected into a new result array.
---@generic K, V, O
---@param T table<K, V>
---@param f fun(value: V, key: K): O?
---@return O[]
function lib.t_map_a(T, f)
	local A = {}
	for k, v in pairs(T) do
		local x = f(v, k)
		if x ~= nil then A[#A + 1] = x end
	end
	return A
end

---Map a table into another table. The mapping function should return
---a key-value pair, or `nil` to omit the entry. The new table will be
---gathered from the returned pairs.
---@generic K, V, L, W
---@param T table<K, V>
---@param f fun(key: K, value: V): L?, W?
---@return table<L, W>
function lib.t_map_t(T, f)
	local U = {}
	for k, v in pairs(T) do
		local k2, v2 = f(k, v)
		if k2 ~= nil then U[k2] = v2 end
	end
	return U
end

---Map over the elements of an array, flattening out one level of arrays.
---@generic I, O
---@param A I[]
---@param f fun(x: I): O[]
---@return O[]
function lib.flat_map(A, f)
	local B = {}
	for i = 1, #A do
		local C = f(A[i])
		if C then
			for j = 1, #C do
				B[#B + 1] = C[j]
			end
		end
	end
	return B
end

---Return an array containing the keys of the given table.
---@generic K
---@param T table<K, any>
---@return K[]
function lib.keys(T)
	local A = {}
	for k in pairs(T) do
		A[#A + 1] = k
	end
	return A
end

---Fisher-Yates shuffle an array in place.
---@generic T
---@param A T[]
function lib.shuffle(A)
	for i = #A, 2, -1 do
		local j = random(i)
		A[i], A[j] = A[j], A[i]
	end
end

---Generates a stateless iterator for use with `for` that iterates over
---groups of items in an array. The array is assumed to consist of items
---pre-sorted on a particular key. The iterator returns subranges of the
---array with equal keys.
function lib.groups(A, key)
	return function(k, i)
		if i > #A then return nil end
		local start = i
		local current = A[i][k]
		while i <= #A and A[i][k] == current do
			i = i + 1
		end
		return i, start, i - 1
	end,
		key,
		1
end

---Given an array of objects pre-sorted on a given key, return an array
---of arrays of those objects grouped by the given key.
---@generic T, K
---@param A T[] The array of objects.
---@param key K The key to group by.
---@return T[][] #An array of arrays, where each sub-array contains objects with the same key.
function lib.group_by(A, key)
	local result = {}
	local i = 1
	while i <= #A do
		local group = {}
		local current = A[i][key]
		while i <= #A and A[i][key] == current do
			group[#group + 1] = A[i]
			i = i + 1
		end
		result[#result + 1] = group
	end
	return result
end

---Given an array of arrays, return a new array of arrays whose members are
---the original arrays, filtered by the given filter function, with empty
---inner arrays dropped.
---@generic T
---@param A T[][] The array of arrays.
---@param f fun(value: T, index: integer): boolean The filter function.
---@return T[][] #A new array of arrays, filtered by the given function.
function lib.filter_groups(A, f)
	local result = {}
	for i = 1, #A do
		local group = filter(A[i], f)
		if #group > 0 then result[#result + 1] = group end
	end
	return result
end

---@param a any[]
---@param i uint
local function irnext(a, i)
	i = i + 1
	if i <= #a then
		local r = a[#a - i + 1]
		return i, r
	else
		return nil, nil
	end
end

---Iterate an array in reverse
---@generic T
---@param a T[]
function lib.irpairs(a) return irnext, a, 0 end

---Filter an array in place.
---@generic T
---@param A T[]
---@param f fun(value: T, index: integer): boolean?
function lib.filter_in_place(A, f)
	local j = 1
	for i = 1, #A do
		if f(A[i], i) then
			A[j] = A[i]
			j = j + 1
		end
	end
	for i = #A, j, -1 do
		A[i] = nil
	end
end

return lib
