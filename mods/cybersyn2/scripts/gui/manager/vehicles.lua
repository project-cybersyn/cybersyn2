local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")

local Pr = relm.Primitive

local lib = {}

lib.VehiclesTab = relm.define(
	"Manager.VehiclesTab",
	function() return ultros.Label("Vehicles") end
)

return lib
