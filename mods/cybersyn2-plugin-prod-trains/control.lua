local events = require("__cybersyn2__.lib.core.event")

events.bind("cybersyn2-prod-train", function(event)
	local train = event.luatrain --[[@as LuaTrain]]
	if (not train) or not train.valid then return end

	-- Inventory sorting
	local inv_sorted = false
	for _, wagon in pairs(train.cargo_wagons) do
		local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
		if inv and inv.valid then
			inv.sort_and_merge()
			inv_sorted = true
		end
	end

	-- OBAF cargo condition removal
	local schedule = train.get_schedule()
	local records = schedule.get_records()
	local obaf_frac = 0.5
	---@type SignalID[]
	local obaf_removed = {}
	if records then
		for rec_i = 1, #records do
			local record = records[rec_i]
			local wait_conditions = record.wait_conditions
			if wait_conditions then
				for cond_i = 1, #wait_conditions do
					local wait_condition = wait_conditions[cond_i]
					if wait_condition.type == "item_count" then
						local item = wait_condition.condition.first_signal --[[@as SignalID]]
						local desired_qty = wait_condition.condition.constant * obaf_frac
						local item_filter = {
							name = item.name,
							quality = item.quality,
							comparator = "=",
						}
						local actual_qty = train.get_item_count(item_filter)
						if actual_qty >= desired_qty then
							obaf_removed[#obaf_removed + 1] = item
							wait_condition.condition.constant = 0
							schedule.change_wait_condition(
								{ schedule_index = rec_i },
								cond_i,
								wait_condition
							)
						end
					elseif wait_condition.type == "fluid_count" then
						local fluid = wait_condition.condition.first_signal --[[@as SignalID]]
						local desired_qty = wait_condition.condition.constant * obaf_frac
						local actual_qty = train.get_fluid_count(fluid.name)
						if actual_qty >= desired_qty then
							obaf_removed[#obaf_removed + 1] = fluid
							wait_condition.condition.constant = 0
							schedule.change_wait_condition(
								{ schedule_index = rec_i },
								cond_i,
								wait_condition
							)
						end
					end
				end
			end
		end
	end

	if inv_sorted or next(obaf_removed) then
		game.print({
			"",
			"Prodded train ",
			event.train_stock,
			" to unstick it.",
			inv_sorted and " (sorted inventory)" or "",
			next(obaf_removed) and " (removed OBAF wait conditions)" or "",
		}, {
			skip = defines.print_skip.never,
			sound = defines.print_sound.never,
		})
	end
end)
