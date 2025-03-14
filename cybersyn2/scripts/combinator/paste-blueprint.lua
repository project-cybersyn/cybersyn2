-- Handle when user pastes a blueprint, which may disrupt the settings
-- of multiple combinators. Do this by invalidating all combinators
-- in the bbox affected by the blueprint

local log = require("__cybersyn2__.lib.logging")

---@param player LuaPlayer
---@param event EventData.on_pre_build
---@param entities BlueprintEntity[]?
local function built_blueprint_entities(player, event, entities)
	if not entities then return end
	log.trace("built_blueprint_entities", player, event, entities)
end

on_built_blueprint(function(player, event)
	-- Determine the actual blueprint being held is ridiculously difficult to do.
	-- h/t Xorimuth on factorio discord for this.
	if player.cursor_record then
		local record = player.cursor_record --[[@as LuaRecord]]
		while record and record.type == "blueprint-book" do
			record = record.contents[record.get_active_index(player)]
		end
		if record and record.type == "blueprint" then
			built_blueprint_entities(player, event, record.get_blueprint_entities())
		end
	elseif player.cursor_stack then
		local stack = player.cursor_stack --[[@as LuaItemStack]]
		if not stack.valid_for_read then return end
		while stack and stack.is_blueprint_book do
			stack = stack.get_inventory(defines.inventory.item_main)[stack.active_index]
		end
		if stack and stack.is_blueprint then
			built_blueprint_entities(player, event, stack.get_blueprint_entities())
		end
	end
end)
