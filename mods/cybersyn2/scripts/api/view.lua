local cs2 = _G.cs2

---@param type string
---@param initial_filter table
---@return Id|nil
function _G.cs2.remote_api.create_view(type, initial_filter)
	if type == "net-inventory" then
		local view = cs2.NetInventoryView:new()
		view:set_filter(initial_filter)
		view:snapshot()
		return view.id
	else
		return nil
	end
end

---@param id Id
---@param filter table
function _G.cs2.remote_api.update_view(id, filter)
	local view = storage.views[id]
	if not view then return false, "View not found" end
	view:set_filter(filter)
	return true
end

---@param id Id
function _G.cs2.remote_api.destroy_view(id)
	local view = storage.views[id]
	if not view then return false, "View not found" end
	view:destroy()
	return true
end

---@param id Id
---@return table|nil
function _G.cs2.remote_api.read_view(id)
	local view = storage.views[id]
	if not view then return nil end
	return view:read()
end
