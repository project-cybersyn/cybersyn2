-- Destroy hidden proxy chest entities.
local function destroy_proxy_chests()
	local n = 0
	for _, surface in pairs(game.surfaces) do
		for _, entity in
			pairs(surface.find_entities_filtered({ name = "cybersyn2-proxy-chest" }))
		do
			entity.destroy()
			n = n + 1
		end
	end
	game.print("Destroyed " .. n .. " cybersyn2-proxy-chests.")
end
destroy_proxy_chests()

-- Make ghost combs into Things.
local function thingify_ghost_combs()
	local n = 0
	for _, surface in pairs(game.surfaces) do
		for _, entity in
			pairs(
				surface.find_entities_filtered({ ghost_name = "cybersyn2-combinator" })
			)
		do
			local err, thing = remote.call(
				"things",
				"create_thing",
				{ entity = entity, tags = entity.tags }
			)
			if err then
				game.print(
					"Error migrating cybersyn2-combinator GHOST at "
						.. serpent.line(entity.position)
						.. " on surface '"
						.. surface.name
						.. "': "
						.. err,
					{ skip = defines.print_skip.never }
				)
			else
				n = n + 1
			end
		end
	end
	game.print("Migrated " .. n .. " cybersyn2-combinator GHOSTs.")
end
thingify_ghost_combs()

local function destroy_comb_storage()
	storage.combinators = {}
	game.print("Cleared combinator storage.")
end
destroy_comb_storage()

local function thingify_real_combs()
	local n = 0
	for _, surface in pairs(game.surfaces) do
		for _, entity in
			pairs(surface.find_entities_filtered({ name = "cybersyn2-combinator" }))
		do
			local tags = storage.combinator_settings_cache[entity.unit_number]
			local err, thing =
				remote.call("things", "create_thing", { entity = entity, tags = tags })
			if err then
				game.print(
					"Error migrating cybersyn2-combinator at "
						.. serpent.line(entity.position)
						.. " on surface '"
						.. surface.name
						.. "': "
						.. err,
					{ skip = defines.print_skip.never }
				)
			else
				n = n + 1
			end
		end
	end
	game.print("Migrated " .. n .. " cybersyn2-combinators.")
end
thingify_real_combs()

local function fixup_storage()
	storage.combinator_settings_cache = nil
	game.print("Cleared combinator settings cache.")
	storage.inventory_links = nil
	game.print("Removed inventory links from storage.")
end
fixup_storage()

game.print("Cybersyn2 migration 0010-alpha-thingify-combinators complete.")

if not storage._SHUTDOWN_DATA then
	game.print(
		"WARNING: This migration requires a shutdown! If you did not perform a shutdown, this game state is now broken. Do not overwite your old save. Downgrade to a previous release, load a backup save, and perform the shutdown procedure before updating again.",
		{ skip = defines.print_skip.never }
	)
end
