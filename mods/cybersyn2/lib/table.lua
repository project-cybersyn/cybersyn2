-- Table and array functions

if ... ~= "__cybersyn2__.lib.table" then
	return require("__cybersyn2__.lib.table")
end

local lib = {}

local empty = setmetatable({}, { __newindex = function() end })

---An empty table enforced via metamethod.
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
function lib.assign(dest, src)
	if not src then return dest end
	for k, v in pairs(src) do
		dest[k] = v
	end
	return dest
end

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
function lib.filter(A, f)
	local B = {}
	for i = 1, #A do
		if f(A[i], i) then B[#B + 1] = A[i] end
	end
	return B
end

---Map an array to an array. Non-nil results of the mapping function
---will be collected into a new result array.
---@generic I, O
---@param A I[]
---@param f fun(value: I, index: integer): O
---@return O[]
function lib.map(A, f)
	local B = {}
	for i = 1, #A do
		local x = f(A[i], i)
		if x ~= nil then B[#B + 1] = x end
	end
	return B
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

return lib
