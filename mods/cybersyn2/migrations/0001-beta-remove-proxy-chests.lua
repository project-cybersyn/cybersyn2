-- Remove lingering proxy chests from deprecated wagon combs.

for _, surface in pairs(game.surfaces) do
	---@cast surface LuaSurface
	local chests =
		surface.find_entities_filtered({ name = "cybersyn2-proxy-chest" })
	for _, chest in ipairs(chests) do
		chest.destroy()
	end
end
