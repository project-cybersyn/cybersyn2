--------------------------------------------------------------------------------
-- Implementation of allow lists
--------------------------------------------------------------------------------

local log = require("__cybersyn2__.lib.logging")
local CarriageType = require("__cybersyn2__.lib.types").CarriageType

local Locomotive = CarriageType.Locomotive
local CargoWagon = CarriageType.CargoWagon
local FluidWagon = CarriageType.FluidWagon

---@param carriage_type Cybersyn.CarriageType?
---@param pattern (0|1|2|3)?
---@param is_strict boolean
---@return boolean
local function carriage_type_matches_pattern(carriage_type, pattern, is_strict)
	if carriage_type == Locomotive then
		return pattern == 0 or pattern == nil
	elseif carriage_type == CargoWagon then
		return pattern == 1 or pattern == 3
	elseif carriage_type == FluidWagon then
		return pattern == 2 or pattern == 3
	elseif carriage_type == nil then
		if is_strict then
			return pattern == 0 or pattern == nil
		else
			return true
		end
	else
		return false
	end
end

---@param stop_layout Cybersyn.TrainStopLayout
---@param train_layout Cybersyn.TrainLayout
---@param is_strict boolean
---@param is_bidi boolean
local function stop_accepts_train(stop_layout, train_layout, is_strict, is_bidi)
	if is_bidi and (not train_layout.bidirectional) then return false end
	local n = math.max(#train_layout.carriage_types, #stop_layout.carriage_loading_pattern)
	for i = 1, n do
		if not carriage_type_matches_pattern(train_layout.carriage_types[i], stop_layout.carriage_loading_pattern[i], is_strict) then return false end
	end
	-- For bidirectional trains, we must check the station can accept the reverse
	-- order of the train as well. Position 1 of the station pattern
	-- should be matched against position train_length of the train layout
	if is_bidi then
		local n_train = #train_layout.carriage_types
		for i = 1, n do
			if not carriage_type_matches_pattern(train_layout.carriage_types[n_train - i + 1], stop_layout.carriage_loading_pattern[i], is_strict) then return false end
		end
	end
	return true
end

---@param stop Cybersyn.TrainStop
---@param is_strict boolean
---@param is_bidi boolean
---@param changed_layout_id Id?
local function make_auto_allow_list(stop, is_strict, is_bidi, changed_layout_id)
	local layout = stop_api.get_layout(stop.id)
	if not layout then
		log.warn("make_auto_allow_list: stop has no layout", stop)
		return
	end
	if not stop.allowed_layouts then stop.allowed_layouts = {} end
	if changed_layout_id then
		local tl = storage.train_layouts[changed_layout_id]
		if not tl then return end
		if stop_accepts_train(layout, tl, is_strict, is_bidi) then
			stop.allowed_layouts[tl.id] = true
		else
			stop.allowed_layouts[tl.id] = nil
		end
	else
		for tl_id, tl in pairs(storage.train_layouts) do
			if stop_accepts_train(layout, tl, is_strict, is_bidi) then
				stop.allowed_layouts[tl_id] = true
			else
				stop.allowed_layouts[tl_id] = nil
			end
		end
	end
	raise_node_data_changed(stop)
end

---@param stop Cybersyn.TrainStop
local function make_all_allow_list(stop)
	stop.allowed_layouts = nil
	stop.allowed_groups = nil
	raise_node_data_changed(stop)
end

---@param stop Cybersyn.TrainStop
---@param allowlist_combinator Cybersyn.Combinator
---@param changed_layout_id Id?
local function make_custom_allow_list(stop, allowlist_combinator, changed_layout_id)
	local allow_mode = combinator_api.read_setting(allowlist_combinator, combinator_settings.allow_mode)
	if allow_mode == "auto" then
		make_auto_allow_list(
			stop,
			combinator_api.read_setting(allowlist_combinator, combinator_settings.allow_strict),
			combinator_api.read_setting(allowlist_combinator, combinator_settings.allow_bidi),
			changed_layout_id
		)
	elseif allow_mode == "all" then
		make_all_allow_list(stop)
	end
end

---@param stop Cybersyn.TrainStop
---@param changed_layout_id Id?
local function make_default_allow_list(stop, changed_layout_id)
	return make_auto_allow_list(stop, false, false, changed_layout_id)
end

---@param stop Cybersyn.TrainStop
---@param changed_layout_id Id?
local function evaluate_stop(stop, changed_layout_id)
	log.trace("Re-evaluating allow list for stop", stop.id)
	local allowlist_combs = node_api.get_associated_combinators(stop, function(comb)
		return combinator_api.read_mode(comb) == "allow"
	end)
	if #allowlist_combs > 1 then
		make_default_allow_list(stop, changed_layout_id)
		-- TODO: warn about multiple combinators
	elseif #allowlist_combs == 0 then
		make_default_allow_list(stop, changed_layout_id)
	else
		make_custom_allow_list(stop, allowlist_combs[1], changed_layout_id)
	end
end

--------------------------------------------------------------------------------
-- Events triggering allow list updates
--------------------------------------------------------------------------------

-- Update on stop layout change
on_train_stop_pattern_changed(function(stop) evaluate_stop(stop) end)

-- When an allowlist combinator is associated with a stop, update its stop.
on_combinator_node_associated(function(combinator, new_node, old_node)
	if combinator_api.read_mode(combinator) == "allow" then
		if old_node and old_node.type == "stop" then
			evaluate_stop(old_node)
		end
		if new_node and new_node.type == "stop" then
			evaluate_stop(new_node)
		end
	end
end)

-- When an allowlist combinator changes settings, update its stop
on_combinator_setting_changed(function(combinator, setting_name, new_value, old_value)
	if combinator_api.read_mode(combinator) == "allow" or (setting_name == "mode" and old_value == "allow") then
		local node = combinator_api.get_associated_node(combinator, "stop") --[[@as Cybersyn.TrainStop?]]
		if node then evaluate_stop(node) end
	end
end)

-- When a train layout is added, update all stops.
on_train_layout_created(function(train_layout)
	for _, node in pairs(storage.nodes) do
		if node.type == "stop" then
			evaluate_stop(node --[[@as Cybersyn.TrainStop]], train_layout.id)
		end
	end
end)
