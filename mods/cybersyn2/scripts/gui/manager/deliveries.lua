local events = require("lib.core.event")
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")
local relm_util = require("lib.core.relm.util")

local Pr = relm.Primitive

local lib = {}

lib.DeliveriesTab = relm.define(
	"Manager.DeliveriesTab",
	function() return ultros.Label("Deliveries") end
)

return lib
