--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

local cs2 = _G.cs2

commands.add_command(
	"cs2-shutdown",
	{ "cybersyn2-commands.shutdown-command-help" },
	function(ev)
		if ev.parameter == "force" then
			cs2.shutdown(true)
		else
			cs2.shutdown(false)
		end
	end
)

commands.add_command(
	"cs2-restart",
	{ "cybersyn2-commands.restart-command-help" },
	function() cs2.restart() end
)

commands.add_command(
	"cs2-debugger",
	{ "cybersyn2-commands.debugger-command-help" },
	function(command) cs2.debug.open_debugger(command.player_index) end
)

commands.add_command(
	"cs2-log-all",
	{ "cybersyn2-commands.log-all-command-help" },
	function() cs2.debug.set_strace(0, 0, nil) end
)

--------------------------------------------------------------------------------
-- Alpha: fix bugged station network migration.
-- XXX: REMOVE FOR RELEASE
--------------------------------------------------------------------------------

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

commands.add_command(
	"cs2-alpha-fix-order-networks",
	"Fix missing order networks due to failed alpha migration.",
	function() enum_real_combs(set_order_networks) end
)

--------------------------------------------------------------------------------
-- Alpha: allow mass switching of stations to single item mode
-- XXX: REMOVE FOR RELEASE
--------------------------------------------------------------------------------

local function set_single_item_mode(entity)
	local err, thing = remote.call("things", "get", entity)
	if not thing then return end
	local combinator = storage.combinators[thing.id]
	if not combinator then return end
	if combinator.mode ~= "station" then return end
	---@diagnostic disable-next-line: undefined-field
	combinator:set_produce_single_item(true)
end

commands.add_command(
	"cs2-alpha-set-single-item-mode",
	"Set all stations to 'provide single item' mode.",
	function() enum_real_combs(set_single_item_mode) end
)
