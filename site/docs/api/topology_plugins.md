# Topology Plugins

A **topology plugin** is a remote callback function that will be run by Cybersyn when it needs to assign a default topology to a node or vehicle.

There are two separate kinds of topology plugins: node topology plugins and vehicle topology plugins. They are called independently depending on the type of object being topologized.

Topology plugins return a topology ID number when they wish to assign an object to a topology, or `nil` if that plugin doesn't wish to register a topology. They may optionally use the API to create a new topology when necessary.

The results from topology plugins are interpreted in a "first-to-answer" fashion -- if a topology plugin returns a topology ID, that ID will be assigned as default and no further topology plugins will be consulted. Consequently, your plugin is not guaranteed to be called on every topology query.

## Registering Topology Plugins

In order to register topology plugins, register your plugin in the `data.lua` phase of your mod by adding an entry to Cybersyn's `mod-data`.

The remote function to be called is identified simply by a two-element array `{interface_name: string, method_name: string}`

An example registration is as follows:

```lua
-- `data.lua`

local node_topology_plugins = data.raw["mod-data"]["cybersyn2"].data.node_topology_plugins
table.insert(node_topology_plugins, {"my_remote_interface", "my_node_callback"})

local vehicle_topology_plugins = data.raw["mod-data"]["cybersyn2"].data.vehicle_topology_plugins
table.insert(vehicle_topology_plugins, {"my_remote_interface", "my_vehicle_callback"})
```

## Implementing Topology Plugins

Once registered, you must also implement the corresponding remote interface function within your `control.lua`:

```lua
-- `control.lua`

---This is the function CS2 will call to topologize a node.
---@param node_id int64 The CS2 node ID.
---@param train_stop LuaEntity? If the node is a train stop, the train stop entity.
---@return int64? topology_id The topology ID to assign, or `nil` to decline assignment.
local function my_node_callback(node_id, train_stop)
  -- Perform your logic here
  return nil
end

---This is the function CS2 will call to topologize a vehicle.
---@param vehicle_id int64 The CS2 vehicle ID.
---@param lua_train LuaTrain? If the vehicle is a train, its LuaTrain.
---@return int64? topology_id The topology ID to assign, or `nil` to decline assignment.
local function my_vehicle_callback(node_id, lua_train)
  -- Perform your logic here
  return nil
end

---Bind the functions to the remote interface you specified earlier in `data.lua`
remote.add_interface("my_remote_interface", {
  my_node_callback = my_node_callback,
  my_vehicle_callback = my_vehicle_callback
})
```

If an implementation matching your registration does not exist, Factorio will crash.
