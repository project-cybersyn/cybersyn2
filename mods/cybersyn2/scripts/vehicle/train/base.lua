local cs2 = _G.cs2

local strsub = string.sub

---@param group_name string
function _G.cs2.train_api.get_train_group(group_name)
	return storage.train_groups[group_name]
end

---@return {[string]: Cybersyn.TrainGroup}
function _G.cs2.train_api.get_train_groups() return storage.train_groups end

---Determine if a vehicle is a fully valid train, including its associated `LuaTrain`.
---@param vehicle Cybersyn.Vehicle?
local function is_valid(vehicle)
	if
		vehicle
		and (vehicle.type == "train")
		and (vehicle --[[@as Cybersyn.Train]]).lua_train
		and (vehicle --[[@as Cybersyn.Train]]).lua_train.valid
	then
		return true
	else
		return false
	end
end
_G.cs2.train_api.is_valid = is_valid

---Determine if a train is valid up to the possibility of missing `LuaTrain`
---due to volatility.
---@param vehicle Cybersyn.Vehicle?
local function is_valid_or_volatile(vehicle)
	if
		vehicle
		and (vehicle.type == "train")
		---@diagnostic disable-next-line: undefined-field
		and (vehicle.volatile or (vehicle.lua_train and vehicle.lua_train.valid))
	then
		return true
	else
		return false
	end
end
_G.cs2.train_api.is_valid_or_volatile = is_valid_or_volatile

---Get a `Cybersyn.Train` by its vehicle id.
---@param vehicle_id Id
---@param skip_validation boolean?
---@return Cybersyn.Train?
function _G.cs2.train_api.get_train(vehicle_id, skip_validation)
	local vehicle = storage.vehicles[vehicle_id]
	if vehicle and (skip_validation or is_valid(vehicle)) then
		return vehicle --[[@as Cybersyn.Train]]
	end
end

---Get a list of vehicle ids for all known Cybersyn trains.
---@return Id[]
function _G.cs2.train_api.get_all_train_ids()
	local train_ids = {}
	for id, vehicle in pairs(storage.vehicles) do
		if vehicle.type == "train" then train_ids[#train_ids + 1] = id end
	end
	return train_ids
end

---Get a `Cybersyn.Train` from a Factorio `LuaTrain` object.
---@param luatrain LuaTrain A *valid* `LuaTrain`.
---@return Cybersyn.Train?
function _G.cs2.train_api.get_train_from_luatrain(luatrain)
	if (not luatrain) or not luatrain.valid then return nil end
	local vid = storage.luatrain_id_to_vehicle_id[luatrain.id]
	if not vid then return nil end
	return storage.vehicles[vid] --[[@as Cybersyn.Train]]
end

---Check if the given group name is considered a Cybersyn train group name.
---@param name string?
---@return boolean
local function is_cybersyn_train_group_name(name)
	local prefix = cs2.CYBERSYN_TRAIN_GROUP_NAME_PREFIX
	return strsub(name or "", 1, #prefix) == prefix
end
_G.cs2.train_api.is_cybersyn_train_group_name = is_cybersyn_train_group_name

---@param train Cybersyn.Train
function _G.cs2.train_api.get_stock(train)
	local lua_train = train.lua_train
	return lua_train
		and lua_train.valid
		and (
			lua_train.front_stock
			or lua_train.back_stock
			or lua_train.carriages[1]
		)
end
