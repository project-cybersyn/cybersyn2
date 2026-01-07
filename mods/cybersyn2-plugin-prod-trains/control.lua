local events = require("__cybersyn2__.lib.core.event")

events.bind("cybersyn2-prod-train", function(event)
	local train = event.luatrain --[[@as LuaTrain]]
	if (not train) or not train.valid then return end
	game.print({
		"",
		"Prodding train ",
		event.train_stock,
		" at ",
		event.stop_entity,
		" to unstick it.",
	}, {
		skip = defines.print_skip.never,
	})
	for _, wagon in pairs(train.cargo_wagons) do
		local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
		if inv and inv.valid then inv.sort_and_merge() end
	end
end)
