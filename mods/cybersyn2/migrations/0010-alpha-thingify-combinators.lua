local n = 0

for _, surface in pairs(game.surfaces) do
	for _, entity in
		pairs(surface.find_entities_filtered({ name = "cybersyn2-combinator" }))
	do
		local err, thing =
			remote.call("things", "create_thing", { entity = entity })
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
