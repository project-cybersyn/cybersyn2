if ... ~= "__cybersyn2__.lib.class" then
	return require("__cybersyn2__.lib.class")
end

local tlib = require("__cybersyn2__.lib.table")

local lib = {}

---Create a class metatable. If `name` is given, registers it with Factorio
---for serialization.
---@param name? string
---@param ... table[] #Mixins
function lib.class(name, ...)
	local mt = {}
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if type(arg) == "table" then
			tlib.assign(mt, arg)
		else
			error("Invalid argument #" .. i .. ": expected table, got " .. type(arg))
		end
	end
	mt.classname = name
	mt.__index = mt
	if script and name then script.register_metatable(name, mt) end
	return mt
end

return lib
