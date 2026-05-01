# Wagon Control

When dealing with cargo orders that might be loading multiple items into multiple wagons, it can be helpful to load the wagons on an individual basis. That is where the wagon control combinator modes can be helpful.

## Wagon Split

By placing one or more combinators in `Wagon Split` mode at a station, you will cause that station to operate in cargo splitting mode.

`Wagon Split` combinators will bind to the wagon nearest their yellow box. You should build one `Wagon Split` combinator for each wagon slot at your station. `Wagon Split` combinators output information specific to the wagon they are attached to, as described below.

Being in cargo splitting mode changes the behaviors of stations in the following ways:

### Cargo Split at Providers

At a provider, arriving trains will generate a split manifest which will distribute the requested items as evenly as possible across each wagon of the train. Cargo filters will also be set on each cargo wagon while the train is loading, ensuring slots are properly allocated to the intended items.

You may read the intended manifest of each wagon from the attached `Wagon Split` combinator. This value will be negative as usual when items are being requested.

Using this information, plus information from the `Wagon Contents` mode described below, you can precisely load orders involving multiple items across multiple wagons.

:::info
Cargo splitting mode does not affect how deliveries are generated. It merely provides an even split of the pre-generated delivery between the wagons of the delivering train.

You **cannot** use cargo splitting mode to ensure that specific cargo is always loaded onto a specific wagon. As usual with Cybersyn, station inventories are black boxes which are expected to be fully accessible by any wagon on the train. Using a merging-chest or warehouse mod can help with this.
:::

### Cargo Split at Requesters

At a requester, arriving trains will have their inventory snapshotted per-wagon on pre-arrival.

Each wagon's inventory can be read as the (positive) output of the `Wagon Split` combinator attached to that wagon.

## Wagon Contents

By placing a combinator in `Wagon Contents` mode, you can read the live contents of an attached **cargo wagon** in a UPS-efficient manner.

`Wagon Contents` combinators will bind to the wagon nearest their yellow box and report live inventory for the attached wagon when a train is parked there.

:::note
`Wagon Contents` mode works *only* with cargo wagons, and *only* at Cybersyn 2 rail stops.
:::
