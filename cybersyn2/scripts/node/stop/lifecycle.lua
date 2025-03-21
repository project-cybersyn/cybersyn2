--------------------------------------------------------------------------------
-- Lifecycle for `TrainStop`s. Code for reassociating combinators to and from
-- train stops is also located here due to cross-cutting concerns.
--------------------------------------------------------------------------------
local tlib = require("__cybersyn2__.lib.table")

---@param stop_entity LuaEntity A *valid* train stop entity.
---@return Cybersyn.TrainStop
local function create_stop_state(stop_entity)
	local stop_id = stop_entity.unit_number
	return node_api.create_node("stop", {
		entity = stop_entity,
		entity_id = stop_id,
		allowed_layouts = {},
		allowed_groups = {},
	}) --[[@as Cybersyn.TrainStop]]
end

on_node_created(function(node)
	if node.type == "stop" then
		storage.stop_id_to_node_id[(node --[[@as Cybersyn.TrainStop]]).entity_id] = node.id
	end
end, true)

on_node_destroyed(function(node)
	if node.type == "stop" then
		-- Attempt to reassociate all combinators associated to this stop.
		if next(node.combinator_set) then
			stop_api.reassociate_combinators(node_api.get_associated_combinators(node))
		end

		-- Remove from entity map
		storage.stop_id_to_node_id[(node --[[@as Cybersyn.TrainStop]]).entity_id or ""] = nil
	end
end, true)

--------------------------------------------------------------------------------
-- Recursive algorithm to correctly associate a set of combinators to the
-- proper nearby rails and stops.
--------------------------------------------------------------------------------
local reassociate_recursive
local create_recursive

---@param combinators Cybersyn.Combinator.Internal[] A list of *valid* combinator states.
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
		local target_stop_entity, target_rail_entity = stop_api.find_associable_entities_for_combinator(combinator.entity)
		---@type Cybersyn.TrainStop?
		local target_stop = nil
		local is_proximate = nil
		if target_stop_entity then
			local stop = stop_api.get_stop_from_unit_number(target_stop_entity.unit_number, true)
			if stop then
				-- Comb already associated with correct stop
				if combinator.node_id == stop.id then goto continue end
				-- Comb needs to be reassociated to target stop.
				target_stop = stop
				is_proximate = true
			else
				-- Comb is causing the creation of a new stop, which needs to be
				-- handled by recursion.
				table.insert(new_stop_entities, target_stop_entity)
			end
		elseif target_rail_entity then
			local stop = stop_api.find_stop_from_rail(target_rail_entity)
			if stop then
				if combinator.node_id == stop.id then goto continue end
				target_stop = stop
			end
		end

		if target_stop and (not target_stop.is_being_destroyed) then
			-- Comb should be associated with the target
			local success, old_stop = node_api.associate_combinator(target_stop, combinator, true)
			if success then
				affected_stop_set[target_stop.id] = true
				if old_stop then
					affected_stop_set[old_stop.id] = true
				end
			end
		else
			-- No or invalid target, comb is now unassociated
			local old_node = node_api.disassociate_combinator(combinator, true)
			if old_node then
				affected_stop_set[old_node.id] = true
			end
		end
		::continue::
	end

	-- Fire batch set-change events for all affected stops
	for stop_id in pairs(affected_stop_set) do
		local stop = stop_api.get_stop(stop_id)
		if stop then
			raise_node_combinator_set_changed(stop)
		end
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
		local stop = stop_api.get_stop_from_unit_number(stop_id, true)
		if stop then
			-- Elide duplicate stop creation.
			goto continue
		end
		-- Create the new stop state.
		stop = create_stop_state(stop_entity)
		-- Recursively reassociate combinators near the new stop.
		local combs = stop_api.find_associable_combinators(stop_entity)
		if #combs > 0 then
			local comb_states = tlib.map(combs, function(comb)
				return combinator_api.get_combinator(comb.unit_number)
			end)
			if #comb_states > 0 then
				reassociate_recursive(comb_states, depth + 1)
			end
		end
		::continue::
	end
end

---Re-evaluate the preferred associations of all the given combinators and
---reassociate them en masse as necessary.
---@param combinators Cybersyn.Combinator.Internal[] A list of *valid* combinator states.
function stop_api.reassociate_combinators(combinators)
	return reassociate_recursive(combinators, 1)
end

--------------------------------------------------------------------------------
-- Event bindings
--------------------------------------------------------------------------------
-- When a stop is built, check for combinators nearby and associate them.
on_built_train_stop(function(stop_entity)
	local combs = stop_api.find_associable_combinators(stop_entity)
	if #combs > 0 then
		local comb_states = tlib.map(combs, function(comb)
			return combinator_api.get_combinator(comb.unit_number)
		end)
		stop_api.reassociate_combinators(comb_states)
	end
end)

-- When a stop is broken, destroy its node.
on_broken_train_stop(function(stop_entity)
	local stop = stop_api.get_stop_from_unit_number(stop_entity.unit_number, true)
	if not stop then return end
	node_api.destroy_node(stop.id)
end)

-- When a combinator is created, try to associate it to train stops
on_combinator_created(function(combinator)
	stop_api.reassociate_combinators({ combinator })
end)

-- Reassociate a combinator if it's repositioned.
on_entity_repositioned(function(what, entity)
	if what == "combinator" then
		local combinator = combinator_api.get_combinator(entity.unit_number)
		if combinator then
			stop_api.reassociate_combinators({ combinator })
		end
	end
end)

-- When a stop loses all its combinators, destroy it
on_node_combinator_set_changed(function(node)
	if node.type == "stop" and not next(node.combinator_set) then
		node_api.destroy_node(node.id)
	end
end)
