-- Table and array functions

if ... ~= "__cybersyn2__.lib.table" then
	return require("__cybersyn2__.lib.table")
end

local lib = {}

---Shallowly copies `src` into `dest`, returning `dest`.
---@generic K, V
---@param dest table<K, V>
---@param src table<K, V>
---@return table<K, V>
function lib.assign(dest, src)
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
		if x ~= nil then
			B[#B + 1] = x
		end
	end
	return B
end

---Map a table into an array. Non-nil results of the mapping function
---will be collected into a new result array.
---@generic K, V, O
---@param T table<K, V>
---@param f fun(value: V, key: K): O
---@return O[]
function lib.t_map_a(T, f)
	local A = {}
	for k, v in pairs(T) do
		local x = f(v, k)
		if x ~= nil then
			A[#A + 1] = x
		end
	end
	return A
end

---Map a table into another table. The mapping function should return
---a key-value pair, or `nil` to omit the entry. The new table will be
---gathered from the returned pairs.
---@generic K, V, L, W
---@param T table<K, V>
---@param f fun(key: K, value: V): L, W
---@return table<L, W>
function lib.t_map_t(T, f)
	local U = {}
	for k, v in pairs(T) do
		local k2, v2 = f(k, v)
		if k2 ~= nil then
			U[k2] = v2
		end
	end
	return U
end

return lib
