# Node Match Veto Plugins

A **node match veto plugin** is a remote callback function that will be run by Cybersyn to check if a particular provider and requester are eligible to match.

The results are "negative" or "veto" based; if any plugin vetoes the match, the match will be skipped and no further plugins will execute.

## Registering a Node Match Veto Plugin

You may register your plugin in the `data.lua` phase of your mod by adding an entry to Cybersyn's `mod-data`.

The remote function to be called is identified simply by a two-element array `{interface_name: string, method_name: string}`

An example registration is as follows:

```lua
-- `data.lua`

local node_match_veto_plugins = data.raw["mod-data"]["cybersyn2"].data.node_match_veto_plugins
table.insert(node_match_veto_plugins, {"my_remote_interface", "my_node_veto_callback"})
```

## Implementing a Node Match Veto Plugin

Once registered, you must also implement the corresponding remote interface function within your `control.lua`:

```lua
-- `control.lua`

---This is the function CS2 will call to check for node-match veto.
---@param requester_id Id CS2 Node ID for requester.
---@param provider_id Id CS2 Node ID for provider.
---@param requester_train_stop LuaEntity? If the requester is a train stop, its stop entity
---@param provider_train_stop LuaEntity? If the provider is a train stop. its stop entity
---@return boolean veto_match `true` if this match should be vetoed.
---@return number workload Empirical orkload estimate.
local function my_node_veto_callback(requester_id, provider_id, requester_train_stop, provider_train_stop)
  -- Perform your logic here
  return false, 0
end

---Bind the function to the remote interface you specified earlier in `data.lua`
remote.add_interface("my_remote_interface", { my_node_veto_callback = my_node_veto_callback })
```

If an implementation matching your registration does not exist, Factorio will crash.

Node match veto plugins run in the logistics thread, and so must return an estimate of their work performed in order to keep CPU usage smooth. This is a purely empirical estimate.
