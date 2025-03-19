---
sidebar_position: 5
---

# Push Logistics

Cybersyn stations can actively push items to other stations designated as storage, rather than waiting for those items to be pulled by a specific request.

## Push Inventory

To push inventory away from a station, place a Cybersyn combinator in `Push` mode within the station's bounding box.

Positive items and fluid signals fed to the input of this combinator constitute the **push inventory** of the station and represent the products and quantities the station wants to offer via push logistics.

:::warning

The push inventory is considered separately from the ordinary "pull" inventory of the station. They may not overlap in any item or fluid; any particular item or fluid must be offered exclusively via either pull or push.

:::

Items offered via push logistics are first offered to the network via normal "pull" logistics. If no ordinary requester can be matched, the system will attempt to match the item with a storage station.

:::note

Ordinary pull logistics always takes priority over push logistics, irrespective of the priority signals given to the stations involved. Any matching requester will always receive deliveries before any storage station.

:::

## Storage Stations

To designate a station as eligible for storage, place a Cybersyn combinator in `Storage` mode within the station's bounding box.

### Item Storage

By giving the `Storage` combinator an input with a positive `Item Slots` virtual signal, you designate the station as an item storage station. The value of the `Item Slots` signal represents the item slot capacity of the storage, and total deliveries will not exceed the given number of slots.

By default, an item storage station will accept any item in any matching push inventory. To restrict item storage to particular items, send positive signals for the desired items to the input of the `Storage` combinator.

### Fluid Storage

By giving the `Storage` combinator an input with a positive `Fluid Capacity` virtual signal, you designate the station as a fluid storage station. Total fluid deliveries dispatched to the storage will not exceed the value of the `Fluid Capacity` signal.

Unlike item storage, fluid storage must explicitly be given an acceptable list of allowed fluids as positive inputs at the `Storage` combinator. In the absence of these signals, no fluid deliveries will be routed.

### Storage Notes

:::note

Storage stations honor networks and channels. In particular, you may use item channels to designate which items can be stored. (Even when using channels, you must still provide an explicit list of allowed fluids to a fluid storage station.)

:::

