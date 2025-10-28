--------------------------------------------------------------------------------
-- Implementation of allow lists
--------------------------------------------------------------------------------

local stlib = require("lib.core.strace")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local cs2 = _G.cs2
local combinator_settings = _G.cs2.combinator_settings
local CarriageType = require("lib.types").CarriageType

---@class Cybersyn.TrainStop
local TrainStop = _G.cs2.TrainStop

local Locomotive = CarriageType.Locomotive
local CargoWagon = CarriageType.CargoWagon
local FluidWagon = CarriageType.FluidWagon
local strace = stlib.strace
local WARN = stlib.WARN
local TRACE = stlib.TRACE
local INF = math.huge
local NINF = -math.huge

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
	if is_bidi and not train_layout.bidirectional then return false end
	local n = math.max(
		#train_layout.carriage_types,
		#stop_layout.carriage_loading_pattern
	)
	for i = 1, n do
		if
			not carriage_type_matches_pattern(
				train_layout.carriage_types[i],
				stop_layout.carriage_loading_pattern[i],
				is_strict
			)
		then
			return false
		end
	end
	-- Train must have at least one loadable carriage.
	local has_loadable = false
	for i = 1, #train_layout.carriage_types do
		if train_layout.carriage_types[i] > 1 then
			has_loadable = true
			break
		end
	end
	if not has_loadable then return false end
	-- For bidirectional trains, we must check the station can accept the reverse
	-- order of the train as well. Position 1 of the station pattern
	-- should be matched against position train_length of the train layout
	if is_bidi then
		local n_train = #train_layout.carriage_types
		for i = 1, n do
			if
				not carriage_type_matches_pattern(
					train_layout.carriage_types[n_train - i + 1],
					stop_layout.carriage_loading_pattern[i],
					is_strict
				)
			then
				return false
			end
		end
	end
	return true
end

---@param stop Cybersyn.TrainStop
---@param is_strict boolean
---@param is_bidi boolean
---@param changed_layout_id Id?
local function make_auto_allow_list(stop, is_strict, is_bidi, changed_layout_id)
	local layout = stop:get_layout()
	if not layout then
		strace(WARN, "message", "make_auto_allow_list: stop has no layout", stop)
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
	cs2.raise_node_data_changed(stop)
	events.raise("cs2.stop_allow_list_changed", stop)
end

---@param stop Cybersyn.TrainStop
local function make_all_allow_list(stop)
	stop.allowed_layouts = nil
	stop.allowed_groups = nil
	cs2.raise_node_data_changed(stop)
	events.raise("cs2.stop_allow_list_changed", stop)
end

---@param stop Cybersyn.TrainStop
---@param allowlist_combinator Cybersyn.Combinator
---@param changed_layout_id Id?
local function make_custom_allow_list(
	stop,
	allowlist_combinator,
	changed_layout_id
)
	local allow_mode =
		allowlist_combinator:read_setting(combinator_settings.allow_mode)
	if allow_mode == "auto" then
		make_auto_allow_list(
			stop,
			allowlist_combinator:read_setting(combinator_settings.allow_strict),
			allowlist_combinator:read_setting(combinator_settings.allow_bidi),
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
	strace(TRACE, "message", "Re-evaluating allow list for stop", stop.id)
	local allowlist_combs = stop:get_associated_combinators(
		function(comb) return comb.mode == "allow" end
	)
	if #allowlist_combs > 1 then
		make_default_allow_list(stop, changed_layout_id)
		cs2.create_alert(
			stop.entity,
			"multiple_allow_list",
			cs2.CS2_ICON_SIGNAL_ID,
			{
				"cybersyn2-alerts.too-many-allowlist",
			}
		)
	elseif #allowlist_combs == 0 then
		make_default_allow_list(stop, changed_layout_id)
		cs2.destroy_alert(stop.entity, "multiple_allow_list")
	else
		make_custom_allow_list(stop, allowlist_combs[1], changed_layout_id)
		cs2.destroy_alert(stop.entity, "multiple_allow_list")
	end
end

---@param stop Cybersyn.TrainStop
local function cull_stop_layouts(stop)
	if not stop.allowed_layouts then return end
	local culled_layout = false
	for layout_id in pairs(stop.allowed_layouts) do
		local layout = storage.train_layouts[layout_id]
		if layout and layout.no_trains then
			stop.allowed_layouts[layout_id] = nil
			culled_layout = true
		end
	end
	if culled_layout then
		cs2.raise_node_data_changed(stop)
		events.raise("cs2.stop_allow_list_changed", stop)
	end
end

--------------------------------------------------------------------------------
-- Events triggering allow list updates
--------------------------------------------------------------------------------

-- Update on stop layout change
cs2.on_train_stop_pattern_changed(function(stop) evaluate_stop(stop) end)

-- When an allowlist combinator is associated with a stop, update its stop.
cs2.on_combinator_node_associated(function(combinator, new_node, old_node)
	if combinator.mode == "allow" then
		if old_node and old_node.type == "stop" then
			evaluate_stop(old_node --[[@as Cybersyn.TrainStop]])
		end
		if new_node and new_node.type == "stop" then
			evaluate_stop(new_node --[[@as Cybersyn.TrainStop]])
		end
	end
end)

-- When an allowlist combinator changes settings, update its stop
cs2.on_combinator_setting_changed(
	function(combinator, setting_name, _, old_value)
		if
			combinator.mode == "allow"
			or (setting_name == "mode" and old_value == "allow")
		then
			local node = combinator:get_node("stop") --[[@as Cybersyn.TrainStop?]]
			if node then evaluate_stop(node) end
		end
	end
)

-- When a train layout is added, update all stops.
cs2.on_train_layout_created(function(train_layout)
	for _, node in pairs(storage.nodes) do
		if node.type == "stop" then
			evaluate_stop(node --[[@as Cybersyn.TrainStop]], train_layout.id)
		end
	end
end)

-- When train layouts are destroyed, we need to re-evaluate all stops.
cs2.on_train_layouts_destroyed(function()
	for _, node in pairs(storage.nodes) do
		if node.type == "stop" then
			cull_stop_layouts(node --[[@as Cybersyn.TrainStop]])
		end
	end
end)

--------------------------------------------------------------------------------
-- Allowlist key calculation
--------------------------------------------------------------------------------

events.bind(
	"cs2.stop_allow_list_changed",
	---@param stop Cybersyn.TrainStop
	function(stop)
		-- Generate allowlist key.
		if stop.allowed_layouts then
			local key_parts = {}
			-- Rely on the deterministic ordering of stored layouts.
			for id in pairs(storage.train_layouts) do
				if stop.allowed_layouts[id] then key_parts[#key_parts + 1] = id end
			end
			-- Generate the final key.
			local key = table.concat(key_parts, "|")
			-- Update the stop's allowlist key.
			stop.allowed_layouts_key = key
		else
			stop.allowed_layouts_key = "ALL"
			return
		end
	end,
	true
)

-- XXX: this is needed in an alpha migration. remove for beta.
function TrainStop:evaluate_allowed_capacities() end
