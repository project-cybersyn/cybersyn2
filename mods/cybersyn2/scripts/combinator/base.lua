--------------------------------------------------------------------------------
-- Base classes and methods for combinators.
--------------------------------------------------------------------------------

local class = require("lib.core.class").class
local tlib = require("lib.core.table")
local signal_lib = require("lib.signal")
local mlib = require("lib.core.math.pos")

local cs2 = _G.cs2
local entity_is_combinator_or_ghost = _G.cs2.lib.entity_is_combinator_or_ghost

local signal_to_key = signal_lib.signal_to_key
local key_to_signal = signal_lib.key_to_signal
local signals_to_signal_counts = signal_lib.signals_to_signal_counts
local distsq = mlib.pos_distsq

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
---@field independent_input_wires boolean? If `true`, the red and green input wires will be read separately when examining the inputs of this combinator.

---@type {[string]: Cybersyn.Combinator.ModeDefinition}
_G.cs2.combinator_modes = {}
local modes = _G.cs2.combinator_modes

--------------------------------------------------------------------------------
-- Combinator
--------------------------------------------------------------------------------

---@class Cybersyn.Combinator
local Combinator = class("Combinator")
_G.cs2.Combinator = Combinator

---Create a new saved combinator state. Should only be called by
---combinator lifecycle controller.
---@param thing things.ThingSummary
---@return Cybersyn.Combinator
function Combinator:new(thing)
	local id = thing.id
	if (not id) or storage.combinators[id] then
		error("Bad or duplicate combinator creation.")
	end
	local obj = setmetatable({ id = id, last_read_tick = 0 }, self)
	if thing.status == "real" then obj.real_entity = thing.entity end
	storage.combinators[id] = obj
	return obj
end

---Check whether this combinator's entity is valid.
---@return boolean? #`true` if the combinator's entity exists and is valid.
function Combinator:is_valid() return true end

---Check whether this combinator has a real, valid entity.
---@return boolean? #`true` if the combinator is real and its entity is valid.
function Combinator:is_real()
	local real_entity = self.real_entity
	return real_entity and real_entity.valid
end

---Retrieve a combinator state from storage by its Thing ID.
---@param thing_id int64? The Thing ID of the combinator to retrieve.
---@param skip_validation? boolean If `true`, blindly returns the storage object without validating actual existence.
---@return Cybersyn.Combinator?
local function get_combinator(thing_id, skip_validation)
	if not thing_id then return nil end
	return storage.combinators[thing_id]
end
_G.cs2.get_combinator = get_combinator

---Destroy a saved combinator state. Should only be called by combinator
---lifecycle.
---@return boolean #Whether the saved state was destroyed.
function Combinator:destroy_state()
	local id = self.id
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
---@param which "red"|"green"|nil If given, and the combinator has independent input wires, read only the given wire. If `nil`, read both wires.
function Combinator:read_inputs(which)
	-- Sanity checks
	-- Don't read invalid entities or ghosts
	local entity = self.real_entity
	if not entity or not entity.valid then return end
	-- Verify input mode
	local mdef = modes[self.mode or ""]
	if not mdef or not mdef.is_input then
		self.inputs = nil
		self.red_inputs = nil
		self.green_inputs = nil
		return
	end
	-- Don't read inputs more than once per tick.
	local now = game.tick
	if now - (self.last_read_tick or 0) < 1 then return end
	self.last_read_tick = now

	if mdef.independent_input_wires then
		-- Read red and green inputs separately
		if which == "red" or which == nil then
			local red_signals = entity.get_signals(RED_INPUTS)
			if red_signals then
				self.red_inputs = signals_to_signal_counts(red_signals)
			else
				self.red_inputs = {}
			end
		end

		if which == "green" or which == nil then
			local green_signals = entity.get_signals(GREEN_INPUTS)
			if green_signals then
				self.green_inputs = signals_to_signal_counts(green_signals)
			else
				self.green_inputs = {}
			end
		end

		self.inputs = nil
	else
		local signals = entity.get_signals(RED_INPUTS, GREEN_INPUTS)
		if signals then
			self.inputs = signals_to_signal_counts(signals)
		else
			self.inputs = {}
		end
		self.red_inputs = nil
		self.green_inputs = nil
	end
end

---Clear all the combinator's outputs.
function Combinator:clear_outputs()
	local entity = self.real_entity
	if not entity or not entity.valid then return end

	local beh = entity.get_or_create_control_behavior() --[[@as LuaDeciderCombinatorControlBehavior]]
	local param = beh.parameters
	param.outputs = {}
	beh.parameters = param
end

---Encode arguments for later use with `direct_write_outputs`.
---Arguments are pairs of `SignalCounts` and
---`int` values representing the signals to add to the output along
---with a multiplier.
function Combinator:encode_outputs(...)
	local outputs = {}

	for i = 1, select("#", ...), 2 do
		local signal_counts = select(i, ...) --[[@as SignalCounts]]
		local sign = select(i + 1, ...) --[[@as number]]
		if signal_counts then
			for key, count in pairs(signal_counts) do
				local signal = key_to_signal(key)
				if signal then
					outputs[#outputs + 1] = {
						signal = signal,
						constant = count * sign,
						copy_count_from_input = false,
					}
				end
			end
		end
	end

	return outputs
end

---Write the combinator's outputs from the given signal counts. Arguments are pairs of `SignalCounts` and
---`int` values representing the signals to add to the output along
---with a multiplier.
function Combinator:write_outputs(...)
	local entity = self.real_entity
	if not entity or not entity.valid then return end
	local beh = entity.get_or_create_control_behavior() --[[@as LuaDeciderCombinatorControlBehavior]]
	local param = beh.parameters
	param.outputs = self:encode_outputs(...)
	beh.parameters = param
end

---Directly replace the combinator's raw outputs.
---@param outputs DeciderCombinatorOutput[]
function Combinator:direct_write_outputs(outputs)
	local entity = self.real_entity
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

local function cross_wires(entity, state)
	local i_red = entity.get_wire_connector(I_RED, true)
	local i_green = entity.get_wire_connector(I_GREEN, true)

	if state then
		local o_red = entity.get_wire_connector(O_RED, true)
		if not i_red.is_connected_to(o_red, SCRIPT) then
			i_red.connect_to(o_red, false, SCRIPT)
		end

		local o_green = entity.get_wire_connector(O_GREEN, true)
		if not i_green.is_connected_to(o_green, SCRIPT) then
			i_green.connect_to(o_green, false, SCRIPT)
		end
	else
		i_red.disconnect_all(SCRIPT)
		i_green.disconnect_all(SCRIPT)
	end
end

---Perform dynamic cross-wiring between combinator input and output pins.
function Combinator:hotwire()
	local combinator_entity = self.real_entity
	if not combinator_entity or not combinator_entity.valid then return end

	local mdef = cs2.combinator_modes[self.mode or ""]
	if mdef then
		if mdef.is_input then
			cross_wires(combinator_entity, true)
		elseif mdef.is_output then
			cross_wires(combinator_entity, false)
		end
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
	local combinator_entity = self.real_entity
	if not combinator_entity or not combinator_entity.valid then return nil end
	local wagons = combinator_entity.surface.find_entities_filtered({
		type = WAGON_TYPES,
		area = rail.bounding_box,
	})
	if #wagons == 0 then return nil end
	if #wagons == 1 then return wagons[1] end
	local pos = self.real_entity.position
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
