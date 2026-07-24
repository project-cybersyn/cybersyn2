--------------------------------------------------------------------------------
-- Use `LuaRendering` to draw relevant debugging information on screen.
--------------------------------------------------------------------------------

local pos_lib = require("lib.core.math.pos")
local bbox_lib = require("lib.core.math.bbox")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local strace = require("lib.core.strace")
local cs2 = _G.cs2
local mod_settings = _G.cs2.mod_settings

---@type Cybersyn.Storage
storage = storage --[[@as Cybersyn.Storage]]

---@class Cybersyn.Internal.DebugOverlayState
---@field public comb_overlays {[UnitNumber]: LuaRenderObject}
---@field public stop_overlays {[UnitNumber]: Cybersyn.Internal.StopDebugOverlayState}
---@field public bbox_overlay LuaRenderObject?

---@class Cybersyn.Internal.StopDebugOverlayState
---@field public text Cybersyn.Internal.MultiLineTextOverlay
---@field public associations LuaRenderObject[]
---@field public bbox LuaRenderObject?

---@class Cybersyn.Internal.MultiLineTextOverlay
---@field public backdrop LuaRenderObject
---@field public text_lines LuaRenderObject[]
---@field public width number
---@field public line_height number

---@param objs LuaRenderObject[]?
local function destroy_render_objects(objs)
	if not objs then return end
	for _, obj in pairs(objs) do
		obj.destroy()
	end
end

---@param state Cybersyn.Internal.MultiLineTextOverlay
local function clear_text_overlay(state)
	if state.backdrop then state.backdrop.destroy() end
	destroy_render_objects(state.text_lines)
end

---@param state Cybersyn.Internal.StopDebugOverlayState
local function clear_stop_overlay(state)
	clear_text_overlay(state.text)
	destroy_render_objects(state.associations)
	if state.bbox then state.bbox.destroy() end
end

local function clear_all_overlays()
	local ovl_data = storage.debug_state and storage.debug_state.overlay
	if not ovl_data then
		strace.trace("clear_all_overlays: no overlay data to clear")
		return
	end
	for _, ovl in pairs(ovl_data.comb_overlays or {}) do
		ovl.destroy()
	end
	for _, ovl in pairs(ovl_data.stop_overlays or {}) do
		clear_stop_overlay(ovl)
	end
	if ovl_data.bbox_overlay then ovl_data.bbox_overlay.destroy() end
	if storage.debug_state then storage.debug_state.overlay = nil end
end

local function enable_or_disable_overlays() clear_all_overlays() end

events.bind("on_shutdown", function() clear_all_overlays() end)

events.bind("cs2.mod_settings_changed", enable_or_disable_overlays)
