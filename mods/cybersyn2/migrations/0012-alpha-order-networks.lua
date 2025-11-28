local function enum_real_combs(f)
	local n = 0
	for _, surface in pairs(game.surfaces) do
		for _, entity in
			pairs(surface.find_entities_filtered({ name = "cybersyn2-combinator" }))
		do
			f(entity)
			n = n + 1
		end
	end
end

local function set_order_networks(entity)
	local err, thing = remote.call("things", "get", entity)
	if (not thing) or not thing.tags then return end
	local combinator = storage.combinators[thing.id]
	if not combinator then return end
	if not thing.tags.order_primary_network then
		remote.call(
			"things",
			"set_tag",
			thing.id,
			"order_primary_network",
			"signal-each"
		)
		if combinator.tag_cache then
			combinator.tag_cache.order_primary_network = "signal-each"
		end
	end
	if not thing.tags.order_secondary_network then
		remote.call(
			"things",
			"set_tag",
			thing.id,
			"order_secondary_network",
			"signal-each"
		)
		if combinator.tag_cache then
			combinator.tag_cache.order_secondary_network = "signal-each"
		end
	end
end

enum_real_combs(set_order_networks)

if not storage._SHUTDOWN_DATA then
	game.print(
		"WARNING: This migration requires a shutdown! If you did not perform a shutdown, this game state is now broken. Do not overwite your old save. Downgrade to a previous release, load a backup save, and perform the shutdown procedure before updating again.",
		{ skip = defines.print_skip.never }
	)
end
