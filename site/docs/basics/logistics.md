---
sidebar_position: 3
---

# Logistics

This section assumes you have read the previous sections and have set up at least one train and two stations. You will now learn to connect those stations and exchange items between them via train logistics.

Information about what items are available or wanted at a given station is provided to Cybersyn through the circuit network.

## Inputs to the Station Combinator

The Station combinator treats the red and green wires differently.

### Primary Wire/True Inventory

The **primary wire** of the Station combinator is the red wire by default. (This can be changed to green in the Station combinator's settings.) It is used to input the station's **true inventory**.

Cybersyn uses a **true inventory model** as the basis for its logistics system. Each station participating in logistics must receive an input giving the total amount of product present at that station. This information is provided to the Station combinator on the primary input wire.

Most often, this is as simple as connecting *all* of your buffer chests and fluid buffers mutually via red wire to the combinator:

(todo: image)

:::note

For those coming from Cybersyn 1, this represents a considerable change. You *MUST NOT* pre-subtract requests from this value as you would have in Cybersyn 1. You *MUST* provide the unaltered total value of present cargo. If you do not, logistics will not function properly.

:::

### Order Wire

The **order wire** of the Station combinator is the opposite wire from the primary wire. By default, the green wire is the order wire. The order wire is used to control the logistics of the station, as will be explained below.

To provide basic signals to the order wire, it is customary to connect it to a constant combinator, which will cover most simple use cases.

## Auto-Providers

The simplest variety of station is the **auto-provider**, which automatically provides all of its available inventory to the logistics system. To make an auto-provider, set the Station combinator's **Cargo** setting to *Outbound only*, then check the box for *Auto provide all*:

(todo: image)

This will cause the station to offer up its entire true inventory (set on the primary wire; see above) as available on the logistic network.

:::note
With an auto-provider, there is no need to provide input on the order wire, except when using advanced networks. The order to provide all the station's contents will automatically be generated.
:::

## Requesting Items

A station may also request items to be brought there. To do so, you must set the Station combinator's **Cargo** setting to allow inbound cargo. (Using either *Inbound Only* or the center setting which allows both inbound and outbound)

Requests are given by providing circuit inputs to the Station combinator's order wire. You must provide a *negative signal* on the order wire indicating how much of what item you would like to request. The value of the signal must be negative and is interpreted as the number of *stacks* of the given item to be requested. You may request multiple distinct items by providing multiple negative signals.

:::note
Requests are interpreted in stacks by default. You may uncheck the *Stacked Requests* checkbox to change this.
:::

## Providing Specific Items

Sometimes you may not wish to provide the entire inventory of a station, but only a subset. In this case, you should make sure your station is in a providing mode, uncheck the *Auto provide all* checkbox, then use *positive signals* on the order wire to specify exactly which items you wish to provide.

The value of each *positive* signal is interpreted as the quantity of that cargo that should be provided. You may provide multiple items by providing multiple distinct positive signals.

:::info
Quantities for provided items are always rounded down to the true inventory provided on the main wire. You may not use the order wire to offer an item that is not present in the true inventory, or quantities beyond what the true inventory shows.
:::

## Loading and Unloading

Once you've set up a provider and a requester, Cybersyn will begin routing trains between them. When trains arrive, they must be loaded and unloaded by your equipment at the station. By convention in the Cybersyn world, *it is the responsibility of the providing station to correctly load a train to the requester's specifications*. Requesters can then simply unload the train's contents knowing that they are getting the proper items.

This can be a challenging problem, which you must solve using standard Factorio train loading and unloading tech. Cybersyn provides a few additional tools to help you in this effort.

:::note
Bugs crop up in all of our designs from time to time, so despite the provider's responsibility, it is often smart to implement filtering/checking at the requester side too!
:::

:::warning
Due to general imprecision in train loading processes, it can be a challenge to load a train correctly according to the manifest. Naive strategies will often overload the train and/or leave cargo stuck in pumps/inserters/loaders. Various strategies for dealing with imprecision are covered in the advanced sections of this documentation.
:::

### Getting the train manifest

When loading or unloading, you will need the train's manifest to know what to load or unload. This is accomplished by placing a combinator in **Train mode** near the station.

This combinator will output the manifest of any parked train. Negative signals represent cargo that should be loaded onto the train. Positive signals represent cargo the train is dropping off.

### Per-wagon cargo

For trains with multiple wagons, it can be helpful to have the manifest split for you on a per-wagon basis. This is where combinators in **Wagon mode** come in. Placing one of these next to the tracks where a wagon will go will cause the manifest to be split on a per-wagon basis. This combinator will then output the wagon-specific manifest.

Wagon mode also applies a cargo slot filter to its connected wagon ensuring that items are slotted correctly. This can be necessary in complex multi-item setups to prevent partial stacks being split over slots.

The Wagon combinator can also be configured to take a UPS-efficient snapshot of the wagon's inventory and automatically add it to the manifest. This can be useful when precisely loading wagons.

:::info
Wagon control does not affect how deliveries are generated. It provides an even split of the delivery between wagons. You cannot use it to ensure that specific cargo is always loaded onto a specific wagon.
:::

## Algorithmic Thresholds

Cybersyn's algorithm automatically decides when it is appropriate to send trains. It does so based primarily on two inputs, both of which can be changed in the *Inbound Item Handling* section of the **Station combinator** options.

### Depletion Threshold

The **depletion threshold** is the percentage of a requested item that must be missing in order for a delivery of that item to be triggered. The threshold is considered separately for each item. Each item whose inventory is depleted by this percentage relative to its requested value will be considered a candidate for delivery. Setting the depletion threshold to 100 means only items that are completely empty are eligible. Setting the depletion threshold to 0 means that any item or fluid missing even one unit is eligible.

### Train fullness threshold

The **train fullness threshold** decides the percentage of a train that should be full before it is dispatched on a delivery. A delivery will only be dispatched if all of the items in the delivery, totaled up, would fill this percentage of the train's item slots, and likewise for fluids.

The fullness threshold can be useful at multi-item stations when it is not desirable to set a high item depletion threshold, but you still don't want excessively empty trains.

:::info
- This value is measured as a percent of *the size of the smallest possible train that would be allowed at the station*. You can control allowed trains using the Allow List. (For example, if you want only full 1-4 trains to come to a station, set the Allow List so only 1-4 trains are on it, then set the train fullness threshold to 100.)

- If the train fullness threshold is set to 0 (the default), the actual threshold for deliveries is determined by the depletion threshold. A delivery must be at least the size of the smallest depletion threshold, even when the fullness threshold is set to 0. To disable thresholds altogether, allowing trains to come with even a single item, both thresholds must be set to 0.
:::

### Notes on thresholds

:::note
- Thresholds are only considered hints to the Cybersyn algorithm. There is not and will never be a guarantee that thresholds will be honored. In particular, Cybersyn contains mechanisms for mitigating starvation in times of scarcity that work by ignoring or overriding thresholds.

- If there is a conflict between threshold values, the requesting station always determines the value of the thresholds used during a delivery.
:::



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
