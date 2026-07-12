# Remote Interface

Individual or one-off commands that can be issued to Cybersyn via remote interface. To retrieve data from Cybersyn, use the query interface.

## Methods

### retopologize
Recalculates default topologies for all vehicles and nodes, then destroys totally empty topologies.

```lua
remote.call("cybersyn2", "retopologize")
```

### get_or_create_topology
Gets or creates a topology with the given name.

```lua
---@param name string Name of the topology to create.
---@return Id? topology_id ID of the topology with the given name, either newly created or existing. `nil` if the topology could not be created.
local topology_id = remote.call("cybersyn2", "get_or_create_topology", name)
```

### fail_delivery
Forces a delivery to fail. Only works if the delivery is in an incomplete state.

```lua
---@param delivery_id Id ID of the delivery to fail.
---@param reason? string Optional reason for the failure.
remote.call("cybersyn2", "fail_delivery", delivery_id, reason)
```

### get_node_vehicle_capacities
Get queues and capacities for a node.

```lua
---@param node_id Id ID of the node to query.
---@return uint? queue_size Size of the queue for the node. Includes all vehicles present or enroute, as well as additional vehicles that may be allowed by the queue_excess setting.
---@return uint? vehicle_capacity Total number of vehicles that can be enroute or at the node simultaneously.
---@return uint? total_deliveries Total number of deliveries for the node.
---@return uint? queue_excess Allowance by which the queue size may exceed the vehicle capacity.
---@return uint? delivery_excess Allowance by which the total deliveries may exceed the vehicle capacity.
local queue_size, vehicle_capacity, total_deliveries, queue_excess, delivery_excess = remote.call("cybersyn2", "get_node_vehicle_capacities", node_id)
```
