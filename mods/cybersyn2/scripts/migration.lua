--------------------------------------------------------------------------------
-- Migration script from Cybersyn to Cybersyn2
--------------------------------------------------------------------------------

local types = require("__cybersyn2__.lib.types")
local cs2 = _G.cs2

-- Cybersyn combinator operation modes
local MODE_PRIMARY_IO = "/"
local MODE_PRIMARY_IO_FAILED_REQUEST = "^"
local MODE_PRIMARY_IO_ACTIVE = "<<"
local MODE_SECONDARY_IO = "%"
local MODE_DEPOT = "+"
local MODE_WAGON = "-"
local MODE_REFUELER = ">>"

-- Cybersyn settings
local SETTING_DISABLE_ALLOW_LIST = 2
local SETTING_IS_STACK = 3
local SETTING_ENABLE_INACTIVE = 4
local SETTING_USE_ANY_DEPOT = 5
local SETTING_DISABLE_DEPOT_BYPASS = 6
local SETTING_ENABLE_SLOT_BARRING = 7
local SETTING_ENABLE_CIRCUIT_CONDITION = 8
local SETTING_ENABLE_TRAIN_COUNT = 9
local SETTING_ENABLE_MANUAL_INVENTORY = 10
local SETTING_DISABLE_MANIFEST_CONDITION = 11

-- Signal for locked slots in cybersyn
local LOCKED_SLOTS = "cybersyn-locked-slots"
local LOCKED_FLUID = "cybersyn-reserved-fluid-capacity"

local function get_front_position(entity)
    local pos = entity.position
    local dir = entity.direction

    if dir == defines.direction.north then
        return {x = pos.x, y = pos.y - 0.5}
    elseif dir == defines.direction.east then
        return {x = pos.x + 0.5, y = pos.y}
    elseif dir == defines.direction.south then
        return {x = pos.x, y = pos.y + 0.5}
    elseif dir == defines.direction.west then
        return {x = pos.x - 0.5, y = pos.y}
    end
end

local function get_back_position(entity)
    local pos = entity.position
    local dir = entity.direction

    if dir == defines.direction.north then
        return {x = pos.x, y = pos.y + 0.5}
    elseif dir == defines.direction.east then
        return {x = pos.x - 0.5, y = pos.y}
    elseif dir == defines.direction.south then
        return {x = pos.x, y = pos.y - 0.5}
    elseif dir == defines.direction.west then
        return {x = pos.x + 0.5, y = pos.y}
    end
end

local function flip_direction(direction)
    if direction == defines.direction.north then
        return defines.direction.south
    elseif direction == defines.direction.south then
        return defines.direction.north
    elseif direction == defines.direction.east then
        return defines.direction.west
    elseif direction == defines.direction.west then
        return defines.direction.east
    end
end

---@param entity LuaEntity
---@return LuaEntity?
local function find_nearby_station(entity)
    local pos = entity.position
    local search_area = {
        { pos.x - 2, pos.y - 2 },
        { pos.x + 2, pos.y + 2 },
    }

    local nearby_stations = entity.surface.find_entities_filtered{
        name = "train-stop",
        area = search_area
    }

    if #nearby_stations == 0 then
        -- No station found nearby
        return nil
    end

    return nearby_stations[1]
end

local function find_input_signal(entity, signal_name)
    local networks = {
        defines.wire_connector_id.combinator_input_red,
        defines.wire_connector_id.combinator_input_green
    }

    for _, network_id in pairs(networks) do
        local network = entity.get_circuit_network(network_id)
        if network then
            -- Check if the locked slots signal is present
            local signals = network.signals
            if signals then
                for _, signal in pairs(signals) do
                    if signal.signal and signal.signal.name == signal_name and signal.signal.type == "virtual" then
                        return signal.count
                    end
                end
            end
        end
    end
end

-- Convert from cybersyn combinator to cybersyn2 combinator
---@param old_entity LuaEntity
local function convert_combinator(old_entity)
    -- Skip if entity is not valid
    if not (old_entity and old_entity.valid) then
        return nil
    end

    -- Get combinator's control behavior
    local control_behavior = old_entity.get_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
    if not control_behavior then
        return nil
    end

    -- Get position and surface for new combinator
    local position = old_entity.position
    local surface = old_entity.surface
    local direction = old_entity.direction
    local force = old_entity.force

    -- Get operation mode (if it exists)
    local op = control_behavior.parameters.operation
    if not op then
        -- Log that we couldn't find an operation parameter
        game.print("Warning: Could not find operation parameter for combinator at " ..
                   position.x .. "," .. position.y)
        return nil
    end

    local config = control_behavior.parameters.second_constant or 0
    local network_signal = control_behavior.parameters.first_signal and control_behavior.parameters.first_signal.name or "signal-A"

    if op == MODE_PRIMARY_IO or op == MODE_PRIMARY_IO_FAILED_REQUEST or op == MODE_PRIMARY_IO_ACTIVE then
        return create_station(old_entity, network_signal, config)
    elseif op == MODE_DEPOT then
        return create_depot(old_entity, config)
    elseif op == MODE_REFUELER then
        old_entity.destroy()
        -- User will need to manually create a refueler
    end
end

function create_station(old_entity, network_signal, config)
    local position = old_entity.position
    local surface = old_entity.surface
    local direction = old_entity.direction
    local force = old_entity.force

    -- Check if this entity has the locked slots signal connected
    local locked_slots_value = find_input_signal(old_entity, LOCKED_SLOTS) or 0
    local locked_fluid_value = find_input_signal(old_entity, LOCKED_FLUID) or 0

    local connections = {}
    local create_train_connector = false
    for _, connector in pairs(old_entity.get_wire_connectors(false)) do
        for _, wire in ipairs(connector.connections) do
            if wire.origin == defines.wire_origin.player then
                if connector.wire_connector_id == defines.wire_connector_id.combinator_output_green or
                    connector.wire_connector_id == defines.wire_connector_id.combinator_output_red then
                    create_train_connector = true
                end
                table.insert(connections, {
                    wire_connector_id = connector.wire_connector_id,
                    wire_type = connector.wire_type,
                    target_entity = wire.target.owner,
                    target_connector_id = wire.target.wire_connector_id
                })
            end
        end
    end

    -- Create new cybersyn2 combinator with error handling
    local new_entity = surface.create_entity{
        name = "cybersyn2-combinator",
        position = get_front_position(old_entity),
        direction = flip_direction(direction),
        force = force,
        fast_replace = false,
        create_build_effect_smoke = true,
        raise_built = true
    }

    if not new_entity then
        return false
    end

    local new_train_comb_entity = nil
    if create_train_connector then
        new_train_comb_entity = surface.create_entity{
            name = "cybersyn2-combinator",
            position = get_back_position(old_entity),
            direction = flip_direction(direction),
            force = force,
            fast_replace = false,
            create_build_effect_smoke = true,
            raise_built = true
        }

        if not new_train_comb_entity then
            game.print("Warning: Failed to create train connector for combinator at " ..
                       position.x .. "," .. position.y)
            return false
        end

        local new_train_combinator = cs2.EphemeralCombinator.new(new_train_comb_entity)
        if new_train_combinator then
           new_train_combinator:write_setting(cs2.combinator_settings.mode, types.CombinatorMode.Manifest)
        end
    end

    -- Handle circuit connections
    local mapped_connections = {
        [defines.wire_connector_id.combinator_input_red] = {
            entity = new_entity,
            wire_connector_id = defines.wire_connector_id.combinator_output_red,
        },
        [defines.wire_connector_id.combinator_input_green] = {
            entity = new_entity,
            wire_connector_id = defines.wire_connector_id.combinator_output_green,
        },
        [defines.wire_connector_id.combinator_output_red] = {
            entity = new_train_comb_entity,
            wire_connector_id = defines.wire_connector_id.combinator_output_red,
        },
        [defines.wire_connector_id.combinator_output_green] = {
            entity = new_train_comb_entity,
            wire_connector_id = defines.wire_connector_id.combinator_output_green,
        },
    }

    for _, conn in pairs(connections) do
        local new_conn = mapped_connections[conn.wire_connector_id]
        if new_conn then
            local new_connector    = new_conn.entity.get_wire_connector(new_conn.wire_connector_id)
            local target_connector = conn.target_entity.get_wire_connector(conn.target_connector_id)
            new_connector.connect_to(target_connector, false, defines.wire_origin.player)
        end
    end

    -- Create an ephemeral combinator reference
    local new_combinator = cs2.EphemeralCombinator.new(new_entity)
    if not new_combinator then
        return false
    end

    local is_pr_state = bit32.extract(config, 0, 2)
    -- Not supported ATM, needs another combinator to handle this
	local allows_all_trains = bit32.extract(config, SETTING_DISABLE_ALLOW_LIST) > 0
	local is_stack = bit32.extract(config, SETTING_IS_STACK) > 0
	local enable_inactive = bit32.extract(config, SETTING_ENABLE_INACTIVE) > 0
	local enable_circuit_condition = bit32.extract(config, SETTING_ENABLE_CIRCUIT_CONDITION) > 0
	local disable_manifest_condition = bit32.extract(config, SETTING_DISABLE_MANIFEST_CONDITION) > 0

    new_combinator:write_setting(cs2.combinator_settings.mode, cs2.MODE_STATION)
    new_combinator:write_setting(cs2.combinator_settings.network_signal, network_signal)
    new_combinator:write_setting(cs2.combinator_settings.pr, is_pr_state)

    new_combinator:write_setting(cs2.combinator_settings.use_stack_thresholds, is_stack)

    if enable_inactive then
        new_combinator:write_setting(cs2.combinator_settings.inactivity_mode, 1)
        new_combinator:write_setting(cs2.combinator_settings.inactivity_timeout, 1)
    end

    if enable_circuit_condition then
        new_combinator:write_setting(cs2.combinator_settings.allow_departure_signal, {
            type = "virtual",
            name = "signal-check",
        })
    end

    if disable_manifest_condition then
        new_combinator:write_setting(cs2.combinator_settings.disable_cargo_condition, true)
    end


    if locked_slots_value > 0 then
        local slots_set = new_combinator:write_setting(cs2.combinator_settings.reserved_slots, locked_slots_value)
        if not slots_set then
            game.print("Warning: Failed to set reserved slots for new combinator")
        end
    end

    if locked_fluid_value > 0 then
        local fluid_set = new_combinator:write_setting(cs2.combinator_settings.reserved_capacity, locked_fluid_value)
        if not fluid_set then
            game.print("Warning: Failed to set reserved fluid for new combinator")
        end
    end

    if old_entity and old_entity.valid then
        old_entity.destroy()
    end

    return true
end

function create_depot(old_entity, config)
    -- Find connected trains to this depot, and add them to a train group
    local train_stop = find_nearby_station(old_entity)
    if train_stop then
        for _, train in pairs(train_stop.get_train_stop_trains()) do
            if train.group == "" then
                train.group = "[virtual-signal=cybersyn2] Train"
            end
        end
    end

    -- Cybersyn2's depots are just regular train stops
    old_entity.destroy()

    return true
end

function _G.cs2.migrate_from_cybersyn()
    if not script.active_mods["cybersyn"] then
        game.print("Cybersyn mod is not active. Migration is not needed.")
        return
    end

    local converted_count = 0
    local failed_count = 0

    --for _, player in pairs(game.players) do
    --   local entity = player.selected
    --   if entity and entity.valid and entity.name == "cybersyn-combinator" then
    --       local new_entity = convert_combinator(entity)
    --   else
    --       game.print("No valid entity selected. Please select a Cybersyn combinator.")
    --   end
    --   return
    --end

    -- Process all surfaces
    for _, surface in pairs(game.surfaces) do
        local cybersyn_combinators = surface.find_entities_filtered{name = "cybersyn-combinator"}
        
        if cybersyn_combinators then
            for _, combinator in pairs(cybersyn_combinators) do
                local new_entity = convert_combinator(combinator)
                if new_entity then
                    converted_count = converted_count + 1
                else
                    failed_count = failed_count + 1
                end
            end
        else
            game.print("Error finding combinators on surface: " .. surface.name)
        end
    end

    game.print("Migration complete: Converted " .. converted_count .. " Cybersyn combinators to Cybersyn2.")
    if failed_count > 0 then
        game.print("Warning: Failed to convert " .. failed_count .. " combinators.")
    end
end