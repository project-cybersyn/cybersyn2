local bit_extract = bit32.extract

for _, combinator in pairs(storage.combinators) do
	local _, thing = remote.call("things", "get", combinator.id)
	if thing then
		local tags = thing.tags or {}
		local flags = tags.order_flags
		if type(flags) ~= "number" then flags = flags and 1 or 0 end

		local changed = false
		if
			not tags.order_primary_reservation_type
			and bit_extract(flags, 2, 1) ~= 0
		then
			remote.call(
				"things",
				"set_tag",
				combinator.id,
				"order_primary_reservation_type",
				"none"
			)
			changed = true
		end
		if
			not tags.order_secondary_reservation_type
			and bit_extract(flags, 3, 1) ~= 0
		then
			remote.call(
				"things",
				"set_tag",
				combinator.id,
				"order_secondary_reservation_type",
				"none"
			)
			changed = true
		end

		if changed then
			combinator.tag_cache = nil
			local node = combinator:get_node()
			if node then node:mark_dirty() end
		end
	end
end
