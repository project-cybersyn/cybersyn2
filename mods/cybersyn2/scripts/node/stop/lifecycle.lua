--------------------------------------------------------------------------------
-- Lifecycle for `TrainStop`s. Code for reassociating combinators to and from
-- train stops is also located here due to cross-cutting concerns.
--------------------------------------------------------------------------------

local tlib = require("__cybersyn2__.lib.table")
local cs2 = _G.cs2
local Combinator = _G.cs2.Combinator
local Node = _G.cs2.Node
local TrainStop = _G.cs2.TrainStop
local Delivery = _G.cs2.Delivery

cs2.on_node_created(function(node)
	if node.type == "stop" then
		storage.stop_id_to_node_id[
			(node --[[@as Cybersyn.TrainStop]]).entity_id
		] =
			node.id
	end
end, true)

cs2.on_node_destroyed(function(node)
	if node.type == "stop" then
		---@cast node Cybersyn.TrainStop
		-- Attempt to reassociate all combinators associated to this stop.
		if next(node.combinator_set) then
			cs2.lib.reassociate_combinators(node:get_associated_combinators())
		end

		-- Remove from entity map
		storage.stop_id_to_node_id[node.entity_id or ""] = nil
	end
end, true)

--------------------------------------------------------------------------------
-- Recursive algorithm to correctly associate a set of combinators to the
-- proper nearby rails and stops.
--------------------------------------------------------------------------------

local reassociate_recursive
local create_recursive

---@param combinators Cybersyn.Combinator[] A list of *valid* combinator states.
---@param depth number The current depth of the recursion.
function reassociate_recursive(combinators, depth)
	if depth > 100 then
		-- This would mean there is a continuous chain of
		-- 50 train stops linked to each other by ambiguous combinators.
		error("reassociate_recursive: Recursion limit reached.")
	end

	-- Node ids of stops whose combinator sets are being changed.
	---@type IdSet
	local affected_stop_set = {}
	-- Stop entities that need to be promoted to new Cybersyn stops.
	-- NOTE: can contain duplicates, recursive creation function should check.
	---@type LuaEntity[]
	local new_stop_entities = {}

	for _, combinator in ipairs(combinators) do
		-- Find the preferred stop for association
		local target_stop_entity, target_rail_entity =
			cs2.lib.find_associable_entities_for_combinator(combinator.entity)
		combinator.connected_rail = target_rail_entity
		---@type Cybersyn.TrainStop?
		local target_stop = nil
		local is_proximate = nil
		if target_stop_entity then
			local stop = TrainStop.get_stop_from_unit_number(
				target_stop_entity.unit_number,
				true
			)
			if stop then
				target_stop = stop
				is_proximate = true
			else
				-- Comb is causing the creation of a new stop, which needs to be
				-- handled by recursion.
				table.insert(new_stop_entities, target_stop_entity)
			end
		elseif target_rail_entity then
			local stop = TrainStop.find_stop_from_rail(target_rail_entity)
			if stop then target_stop = stop end
		end

		if target_stop and not target_stop.is_being_destroyed then
			if combinator.node_id ~= target_stop.id then
				-- Comb should be associated with the target
				local success, old_stop =
					target_stop:associate_combinator(combinator, true)
				if success then
					affected_stop_set[target_stop.id] = true
					if old_stop then affected_stop_set[old_stop.id] = true end
				end
			end
		else
			-- No or invalid target, comb is now unassociated
			local old_node = Node.disassociate_combinator(combinator, true)
			if old_node then affected_stop_set[old_node.id] = true end
		end
	end

	-- Fire batch set-change events for all affected stops
	for stop_id in pairs(affected_stop_set) do
		local stop = Node.get(stop_id)
		if stop then cs2.raise_node_combinator_set_changed(stop) end
	end

	-- Create new stops as needed, recursively reassociating combinators near
	-- the created stops.
	if #new_stop_entities > 0 then
		create_recursive(new_stop_entities, depth + 1)
	end
end

---@param stop_entities LuaEntity[] A list of *valid* train stop entities that are not already Cybersyn stops. They will be promoted to Cybersyn stops.
---@param depth number The current depth of the recursion.
function create_recursive(stop_entities, depth)
	if depth > 100 then
		-- This would mean there is a continuous chain of
		-- 50 train stops linked to each other by ambiguous combinators.
		error("create_recursive: Recursion limit reached.")
	end

	for _, stop_entity in ipairs(stop_entities) do
		local stop_id = stop_entity.unit_number --[[@as uint]]
		local stop = TrainStop.get_stop_from_unit_number(stop_id, true)
		if not stop then
			-- Create the new stop state.
			stop = TrainStop.new(stop_entity)
			-- Recursively reassociate combinators near the new stop.
			local combs = cs2.lib.find_associable_combinators(stop_entity)
			if #combs > 0 then
				local comb_states = tlib.map(
					combs,
					function(comb) return Combinator.get(comb.unit_number) end
				)
				if #comb_states > 0 then
					reassociate_recursive(comb_states, depth + 1)
				end
			end
		end
	end
end

---Re-evaluate the preferred associations of all the given combinators and
---reassociate them en masse as necessary.
---@param combinators Cybersyn.Combinator[] A list of *valid* combinator states.
function _G.cs2.lib.reassociate_combinators(combinators)
	return reassociate_recursive(combinators, 1)
end

--------------------------------------------------------------------------------
-- Event bindings
--------------------------------------------------------------------------------

-- When a stop is built, check for combinators nearby and associate them.
cs2.on_built_train_stop(function(stop_entity)
	local combs = cs2.lib.find_associable_combinators(stop_entity)
	if #combs > 0 then
		local comb_states = tlib.map(
			combs,
			function(comb) return Combinator.get(comb.unit_number) end
		)
		cs2.lib.reassociate_combinators(comb_states)
	end
end)

-- When a stop is broken, destroy its node.
cs2.on_broken_train_stop(function(stop_entity)
	local stop =
		TrainStop.get_stop_from_unit_number(stop_entity.unit_number, true)
	if not stop then return end
	stop:destroy()
end)

-- When a combinator is created, try to associate it to train stops
cs2.on_combinator_created(
	function(combinator) cs2.lib.reassociate_combinators({ combinator }) end
)

-- When a stop loses all its combinators, destroy it
cs2.on_node_combinator_set_changed(function(node)
	-- TODO: uncovered case: when none of the combinators are within yellow
	-- radius of stop, destroy stop
	if node.type == "stop" and not next(node.combinator_set) then
		node:destroy()
	end
end)

-- When a stop is destroyed, fail all its deliveries.
cs2.on_node_destroyed(function(node)
	if node.type ~= "stop" then return end
	---@cast node Cybersyn.TrainStop
	tlib.for_each(node.deliveries, function(_, delivery_id)
		local delivery = Delivery.get(delivery_id, true)
		if delivery then delivery:fail() end
	end)
end)
