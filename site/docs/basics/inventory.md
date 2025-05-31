---
sidebar_position: 3
---

# Inventory

Information about what products are available at a given station is provided to Cybersyn through the circuit network.

## Providing Items

A station will provide a product to its [networks](./networks.md) when **a positive item or fluid signal is sent to the input of a `Station` combinator that is set to allow provision**.

The value of the signal indicates the quantity of the item or fluid that is available for pickup.

## Requesting Items

### Request thresholds

## Multiple Items

It is possible for a station to request and provide as many items as desired by feeding the appropriate signals into the `Station` combinator.

:::note

A single station cannot both request and provide the same item.

:::

### Reading the train's manifest

### Wagon control

## Notes on Inventory

### Inventories are Unified

:::note

From the point of view of Cybersyn, a station's inventory is considered a single bucket of items and/or fluids. Even when wagon control is employed, there is no way to direct particular items to particular train cars.

This means that all train cars at the station must have access to the station's entire advertised inventory. For this purpose, it can be convenient to use a merging chest or warehouse mod.

:::

### Inventories are Not Realtime

:::note

- For performance reasons, station inventory is not processed in realtime. Station inventories are updated periodically in the background. In saves with very large number of stations, this can result in any one station taking quite some time to update its inventory.
This can be mitigated if necessary by changing Cybersyn's performance settings.

- A station's inventory will not be updated while a train is at the station, as this will result in the delivery of that train being unaccounted for. Instead, the station will update its inventory opportunistically as the train leaves.

:::
