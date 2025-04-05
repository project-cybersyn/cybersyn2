if ... ~= "__cybersyn2__.lib.class" then
	return require("__cybersyn2__.lib.class")
end

local tlib = require("__cybersyn2__.lib.table")

local lib = {}

function lib.class(name, extends)
	local mt = {}
	if extends then tlib.assign(mt, extends) end
	mt.__index = mt
	if script then script.register_metatable(name, mt) end
	return mt
end

return lib
