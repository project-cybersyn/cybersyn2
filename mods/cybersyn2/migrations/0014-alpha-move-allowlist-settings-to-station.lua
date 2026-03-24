for _, node in pairs(storage.nodes) do
	if node.type == "stop" then
		---@cast node Cybersyn.TrainStop
		local station_comb = node:get_combinator_with_mode("station")
		local allowlist_comb = node:get_combinator_with_mode("allow")
		if allowlist_comb and station_comb then
			-- If there's an allowlist combinator, we need to update the allow list according to its settings.
			local allow_mode = allowlist_comb:get_allow_mode()
			if allow_mode == "auto" then
				station_comb:set_allow_all(false)
				station_comb:set_allow_strict(allowlist_comb:get_allow_strict())
				station_comb:set_allow_bidi(allowlist_comb:get_allow_bidi())
			elseif allow_mode == "all" then
				station_comb:set_allow_all(true)
				station_comb:set_allow_strict(false)
				station_comb:set_allow_bidi(false)
			end
		end
	end
end
