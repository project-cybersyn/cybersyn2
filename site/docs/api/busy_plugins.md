# Busy Plugins

A **busy plugin** is a remote callback function that will be run by Cybersyn when it needs to determine if a particular vehicle is busy. This can be used by other mods to prevent Cybersyn from utilizing vehicles that your mod deems to be otherwise occupied.

The results from busy plugins are "negative" or "veto" based; if any plugin says the vehicle is busy, it will be marked busy even if another plugin would have returned not busy.

Consequently, your plugin is not guaranteed to be called on every busy check: if Cybersyn itself, or another registered plugin, finds a vehicle to be busy, your plugin will be skipped.

## Registering a Busy Plugin

In order to register a busy plugin, your mod must depend on `cybersyn2`. You may then register your plugin in the `data.lua` phase of your mod by adding an entry to Cybersyn's `mod-data`.

The remote function to be called is identified simply by a two-element array `{interface_name: string, method_name: string}`

An example registration is as follows:

```lua
-- `data.lua`

local busy_plugins = data.raw["mod-data"]["cybersyn2"].data.busy_plugins
table.insert(busy_plugins, {"my_remote_interface", "my_busy_callback"})
```

## Implementing a Busy Plugin

Once registered, you must also implement the corresponding remote interface function within your `control.lua`:

```lua
-- `control.lua`

---This is the function CS2 will call to check if a train is busy.
---@param vehicle_id int64 The CS2 vehicle ID.
---@param lua_train LuaTrain? If the vehicle is a train, its LuaTrain (if it exists).
---@return boolean is_busy `true` if this train should be considered busy.
local function my_busy_callback(vehicle_id, lua_train)
  -- Perform your busy-check logic here
  return false
end

---Bind the function to the remote interface you specified earlier in `data.lua`
remote.add_interface("my_remote_interface", { my_busy_callback = my_busy_callback })
```

If an implementation matching your registration does not exist, Factorio will crash.
