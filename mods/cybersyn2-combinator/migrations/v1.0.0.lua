local constants = require "scripts.constants"
local CybersynCombinator = require "scripts.combinator"

local filter = {
    name = constants.ENTITY_NAME
}
for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered(filter)
    for _, entity in pairs(entities) do
        if entity.valid then
            local combinator = CybersynCombinator:new(entity, false)
            local pr = combinator:get_cs_value(constants.SETTINGS.CS_PRIORITY_NAME)
            if pr == constants.SETTINGS.CS_DEFAULT_PRIORITY then
                local old_pr = settings.global[constants.SETTINGS.CS_PRIORITY_OLD].value
                if old_pr then
                    combinator:set_cs_value(constants.SETTINGS.CS_PRIORITY_NAME, old_pr)
                end
            end
        end
    end
end
