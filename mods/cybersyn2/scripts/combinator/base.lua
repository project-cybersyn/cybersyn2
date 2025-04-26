--------------------------------------------------------------------------------
-- Base classes and methods for combinators.
--------------------------------------------------------------------------------

local class = require("__cybersyn2__.lib.class").class
local tlib = require("__cybersyn2__.lib.table")
local signal_lib = require("__cybersyn2__.lib.signal")
local mlib = require("__cybersyn2__.lib.math")

local cs2 = _G.cs2
local entity_is_combinator_or_ghost = _G.cs2.lib.entity_is_combinator_or_ghost

local signal_to_key = signal_lib.signal_to_key
local key_to_signal = signal_lib.key_to_signal
local distsq = mlib.pos_distsq

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

---@alias Cybersyn.Combinator.SettingReader fun(definition: Cybersyn.Combinator.SettingDefinition, combinator: Cybersyn.Combinator.Ephemeral): any Reads a setting from a combinator. `nil` return value indicates the setting was absent.
---@alias Cybersyn.Combinator.SettingWriter fun(definition: Cybersyn.Combinator.SettingDefinition, combinator: Cybersyn.Combinator.Ephemeral, value: any): boolean Writes a setting to a combinator. Returns `true` if the write was successful.

---@class (exact) Cybersyn.Combinator.SettingDefinition Definition of a setting that can be stored on a Cybersyn combinator.
---@field public name string The unique name of the setting.
---@field public reader Cybersyn.Combinator.SettingReader The function used to read this setting from a combinator.
---@field public writer Cybersyn.Combinator.SettingWriter? The function used to write this setting to a combinator.

---Global table of combinator settings definitions
---@type table<string, Cybersyn.Combinator.SettingDefinition>
_G.cs2.combinator_settings = {}

--------------------------------------------------------------------------------
-- Modes
--------------------------------------------------------------------------------

---@class (exact) Cybersyn.Combinator.ModeDefinition
---@field name string The name of the mode, which must be unique. Used as the internal storage key for the mode.
---@field localized_string string The Factorio localized string for the mode.
---@field settings_element string? Name of a Relm element to use as the GUI settings element for this mode. Will be passed the active combinator as a `combinator` prop. If not provided, a noninteractive placeholder element will be rendered.
---@field help_element string? Name of a Relm element to use as the GUI help element for this mode. Will be passed the active combinator as a `combinator` prop. If not provided, a noninteractive placeholder element will be rendered.
---@field is_input boolean? `true` if the input signals of a combinator in this mode should be read during `poll_combinators`.
---@field is_output boolean? `true` if this mode can set the output state of the combinator.

---@type {[string]: Cybersyn.Combinator.ModeDefinition}
_G.cs2.combinator_modes = {}
local modes = _G.cs2.combinator_modes

--------------------------------------------------------------------------------
-- EphemeralCombinator
--------------------------------------------------------------------------------

---@class Cybersyn.Combinator.Ephemeral
local EphemeralCombinator = class("EphemeralCombinator")
_G.cs2.EphemeralCombinator = EphemeralCombinator

---Create a new ephemeral combinator reference
---@return Cybersyn.Combinator.Ephemeral?
function EphemeralCombinator.new(entity)
	if entity_is_combinator_or_ghost(entity) then
		return setmetatable({ entity = entity }, EphemeralCombinator)
	else
		return nil
	end
end

function EphemeralCombinator:is_valid() return self.entity and self.entity.valid end

---@return boolean is_ghost `true` if combinator is a ghost
---@return boolean is_valid `true` if combinator is valid, ghost or no
function EphemeralCombinator:is_ghost()
	local entity = self.entity
	if not entity or not entity.valid then return false, false end
	if entity.name == "entity-ghost" then
		return true, true
	else
		return false, true
	end
end

---Attempt to convert an ephemeral combinator reference to a realized combinator reference.
---@return Cybersyn.Combinator?
function EphemeralCombinator:realize()
	local entity = self.entity
	if entity and entity.valid then
		local combinator = storage.combinators[entity.unit_number]
		if combinator and (combinator == self or combinator:is_valid()) then
			return combinator
		end
	end
	return nil
end

---@param entity LuaEntity
local function get_raw_settings(entity)
	local id = entity.unit_number
	local cache = storage.combinator_settings_cache[id]
	if cache then return cache end
	return entity.tags or {}
end
_G.cs2.get_raw_settings = get_raw_settings

---@param entity LuaEntity
---@param values Tags
local function set_raw_settings(entity, values)
	-- If ghost, store in tags.
	if entity.name == "entity-ghost" then
		entity.tags = values
		return true
	end
	local id = entity.unit_number --[[@as UnitNumber]]
	local combinator = storage.combinators[id]
	if not combinator then return false end
	-- Defensive copy to avoid possible storage cross-references
	storage.combinator_settings_cache[id] = tlib.deep_copy(values, true)
	return true
end

---@param entity LuaEntity
---@param key string
---@param value boolean|string|number|Tags|nil
---@return boolean #`true` if the value was stored, `false` if not.
local function set_raw_setting(entity, key, value)
	-- If ghost, store in tags.
	if entity.name == "entity-ghost" then
		local tags = entity.tags or {}
		tags[key] = value
		entity.tags = tags
		return true
	end
	-- If not ghost, update cache
	local id = entity.unit_number
	local combinator = storage.combinators[id]
	if not combinator then return false end
	local cache = storage.combinator_settings_cache[id]
	if not cache then return false end
	cache[key] = value
	return true
end

---Get raw settings values for this combinator as a Tags table
---@return Tags
function EphemeralCombinator:get_raw_settings()
	return get_raw_settings(self.entity)
end

---Get a raw setting value for this combinator.
---@param key string
---@return boolean|string|number|Tags|nil
function EphemeralCombinator:get_raw_setting(key)
	return get_raw_settings(self.entity)[key]
end

---Apply raw settings to this combinator or ghost, overwriting all existing
---settings.
---@param settings Tags
---@return boolean #`true` if the value was stored, `false` if not.
function EphemeralCombinator:set_raw_settings(settings)
	return set_raw_settings(self.entity, settings)
end

---Set the key to the given value in the combinator's raw settings.
---@param key string
---@param value boolean|string|number|Tags|nil
---@return boolean #`true` if the value was stored, `false` if not.
function EphemeralCombinator:set_raw_setting(key, value)
	return set_raw_setting(self.entity, key, value)
end

---Read the value of a combinator setting.
---@param setting Cybersyn.Combinator.SettingDefinition
---@return any value The value of the setting.
function EphemeralCombinator:read_setting(setting)
	return setting.reader(setting, self)
end

---Change the value of a combinator setting.
---@param setting Cybersyn.Combinator.SettingDefinition
---@param value any
---@param skip_event boolean? If `true`, the setting changed event will not be raised.
---@return boolean #`true` if a changed value was written.
function EphemeralCombinator:write_setting(setting, value, skip_event)
	local old = setting.reader(setting, self)
	if old == value then return false end
	local writer = setting.writer
	if not writer then return false end
	local written = writer(setting, self, value)
	if written and not skip_event then
		cs2.raise_combinator_or_ghost_setting_changed(
			self,
			setting.name,
			value,
			old
		)
	end
	return written
end

--------------------------------------------------------------------------------
-- Combinator
--------------------------------------------------------------------------------

---@class Cybersyn.Combinator
local Combinator = class("Combinator", EphemeralCombinator)
_G.cs2.Combinator = Combinator

---Create a new saved combinator state. Should only be called by
---combinator lifecycle controller.
---@param entity LuaEntity
---@return Cybersyn.Combinator
function Combinator.new(entity)
	local id = entity.unit_number
	if (not id) or storage.combinators[id] then
		error("Bad or duplicate combinator creation.")
	end
	storage.combinators[id] =
		setmetatable({ id = id, entity = entity }, Combinator)
	return storage.combinators[id]
end

---Retrieve a combinator state from storage by its entity's `unit_number`.
---@param unit_number UnitNumber?
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.Combinator?
local function get_combinator(unit_number, skip_validation)
	if not unit_number then return nil end
	local combinator = storage.combinators[unit_number]
	if skip_validation then
		return combinator
	elseif combinator then
		return combinator:is_valid() and combinator or nil
	end
end
Combinator.get = get_combinator
_G.cs2.get_combinator = get_combinator

---Destroy a saved combinator state. Should only be called by combinator
---lifecycle.
---@return boolean #Whether the saved state was destroyed.
function Combinator:destroy_state()
	local id = self.id
	storage.combinator_settings_cache[id] = nil
	if storage.combinators[id] then
		storage.combinators[id] = nil
		return true
	end
	return false
end

---Get the node associated with this combinator if any, optionally filtering
---by node type.
---@param check_type string?
---@return Cybersyn.Node?
function Combinator:get_node(check_type)
	local node = storage.nodes[self.node_id or ""]
	if node and (not check_type or node.type == check_type) then return node end
end

local RED_INPUTS = defines.wire_connector_id.combinator_input_red
local GREEN_INPUTS = defines.wire_connector_id.combinator_input_green

---If the combinator is in an input-supporting mode, read and cache its input
---signals.
function Combinator:read_inputs()
	-- Sanity check
	local mdef = modes[self.mode or ""]
	if not mdef or not mdef.is_input then
		self.inputs = nil
		return
	end
	local entity = self.entity
	if not entity or not entity.valid then return end

	-- Read input sigs
	local signals = entity.get_signals(RED_INPUTS, GREEN_INPUTS)
	if signals then
		---@type SignalCounts
		local inputs = {}
		for i = 1, #signals do
			local signal = signals[i]
			inputs[signal_to_key(signal.signal)] = signal.count
		end
		self.inputs = inputs
	else
		self.inputs = {}
	end
end

---Write the combinator's outputs from the given signal counts. `nil`
---clears all outputs.
---@param signal_counts SignalCounts?
---@param sign number Multiplier for signal counts, -1 to invert.
function Combinator:write_outputs(signal_counts, sign)
	local entity = self.entity
	if not entity or not entity.valid then return end

	local beh = entity.get_or_create_control_behavior() --[[@as LuaDeciderCombinatorControlBehavior]]
	local param = beh.parameters
	local outputs = {}
	if signal_counts then
		for key, count in pairs(signal_counts) do
			local signal = key_to_signal(key)
			if signal then
				outputs[#param.outputs + 1] = {
					signal = signal,
					constant = count * sign,
					copy_count_from_input = false,
				}
			end
		end
	end
	param.outputs = outputs
	beh.parameters = param
end

---@param outputs DeciderCombinatorOutput[]
function Combinator:direct_write_outputs(outputs)
	local entity = self.entity
	if not entity or not entity.valid then return end
	local beh = entity.get_or_create_control_behavior() --[[@as LuaDeciderCombinatorControlBehavior]]
	local param = beh.parameters
	param.outputs = outputs
	beh.parameters = param
end

local I_RED = defines.wire_connector_id.combinator_input_red
local I_GREEN = defines.wire_connector_id.combinator_input_green
local O_RED = defines.wire_connector_id.combinator_output_red
local O_GREEN = defines.wire_connector_id.combinator_output_green
local SCRIPT = defines.wire_origin.script

---@param state boolean `true` if wires should be crossed, `false` if uncrossed.
function Combinator:cross_wires(state)
	local combinator_entity = self.entity
	if not combinator_entity or not combinator_entity.valid then return end

	local i_red = combinator_entity.get_wire_connector(I_RED, true)
	local i_green = combinator_entity.get_wire_connector(I_GREEN, true)

	if state then
		local o_red = combinator_entity.get_wire_connector(O_RED, true)
		if not i_red.is_connected_to(o_red, SCRIPT) then
			i_red.connect_to(o_red, false, SCRIPT)
		end

		local o_green = combinator_entity.get_wire_connector(O_GREEN, true)
		if not i_green.is_connected_to(o_green, SCRIPT) then
			i_green.connect_to(o_green, false, SCRIPT)
		end
	else
		i_red.disconnect_all(SCRIPT)
		i_green.disconnect_all(SCRIPT)
	end
end

local WAGON_TYPES = { "locomotive", "cargo-wagon", "fluid-wagon" }

---For a combinator associated with a rail, find the wagon the combinator
---is pointing at if any.
---@return LuaEntity? wagon The wagon the combinator is pointing at.
function Combinator:find_connected_wagon()
	-- TODO: this can be slightly optimized by looking at a 1x1 square
	-- around the combinator (its bbox shifted 1 tile towards the rail)
	-- instead of the whole rail.
	local rail = self.connected_rail
	if not rail then return nil end
	local wagons = self.entity.surface.find_entities_filtered({
		type = WAGON_TYPES,
		area = rail.bounding_box,
	})
	if #wagons == 0 then return nil end
	if #wagons == 1 then return wagons[1] end
	local pos = self.entity.position
	local closest = math.huge
	local wagon = nil
	for i = 1, #wagons do
		local w = wagons[i]
		local dist = distsq(pos, w.position)
		if dist < closest then
			wagon = w
			closest = dist
		end
	end
	return wagon
end
