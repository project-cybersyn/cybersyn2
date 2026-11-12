# Advanced Orders

The order system has a number of additional features beyond the basic level.

## Multiple Orders

By default, a station is created with a single order which is controlled by the *order wire* of its Station combinator.

You may create additional orders for a station by building additional combinators in **Orders** mode.

Each such combinator adds two additional orders to the station, one for each color of input wire. Each of the two input wires to an **Orders** combinator are treated as two separate *order wires*, with the same inputs and settings as every other order wire.

### Orders Share Inventory

While each order has independent networks, provide, and request values, all orders at a given station share that station's true inventory.

This means that individual orders can cooperatively offer distinct subsets of the station's inventory to different networks at different times.

Orders are each measured separately against the station's true inventory, capped by the amount of the largest order, i.e. the upper limit for the total of all requests or provides is defined by the largest order, not the sum of all orders.

:::info
This is best illustrated with some examples:

1) Two requesting orders for -1000 iron on network A and B will result in the station receiving -1000 iron from whichever the first network is that can provide it. (NOTE: *not* 2000 iron)
2) A requesting order of -1000 iron on network A with priority 1 and -2000 iron on network B with priority 0 will result in the station first receiving 1000 iron from network A (assuming availability) and then 1000 from network B. (NOTE: 2000 iron is the largest order, hence a total of 2000 iron will flow, not 3000)
3) If a station has 5000 iron, is providing 5000 iron to network A with priority 0, and 3000 iron to network B with priority 1, it will send 3000 to a requester on network B before sending a further 2000 to a requester on network A. (NOTE: 5000 iron is the largest order, hence a total of 5000 iron will flow, not 8000)

This system is incredibly powerful and can solve virtually any logistics problem, including byproduct handling, voiding, push/pull systems, and many more.

See the Cookbook for further practical examples.
:::

## Exotic Orders

By providing certain special inputs to an *order wire*, requests with advanced behaviors can be generated.

### Quality Spread

If, along with a standard set of negative request values, additional signals of type `quality` are fed into a requesting order wire with nonzero values, this will generate a **quality spread order**.

Such an order is requesting the given items in the given total quantity like a normal order, except that **the quality of each item must be among the given qualities (and may be any of those).**

For example, the following order:

`{iron-plate: -100, legendary: 1, epic: 1 }`

TODO: screenshot

is requesting 100 iron plates whose quality must be either legendary or epic. Iron plates of lower qualities will not be delivered to this requester.

### "All Items" orders

If the `All Items` virtual signal is given with a **negative** value `-N` on an order wire, and no negative `item` signals are present, it represents a request for **N stacks** of *any combination of items*. This can be used to make stations that will sink any item.

Depletion thresholds apply to "All Items" orders as a percentage of the number `N` of requested stacks.

Manually-set per-item thresholds DO NOT work with "All Items" orders.

"All Items" orders support quality spread as well, so if `quality` signals are present alongside the `All Items` signal, the items must be among those qualities.

### OR orders

If the `All Items` virtual signal is given with a **negative** value `-N` along with a number of `item` signals with **negative** values, it represents a request for **N stacks** of *any combination* of the given items.

The item signals are treated as a mask, so their values do not matter as long as they are negative.

Depletion thresholds apply to "OR" orders as a percentage of the number `N` of requested stacks.

Manually-set per-item thresholds DO NOT work with OR orders.

OR orders support quality spread, so if `quality` signals are present, the items must be among those qualities.

## Push Orders

A nonzero `Push` virtual signal on an order wire makes that order a **push order**. Its cargo signals skip the regular matching loop and go to the push phase.

The push phase runs after the regular loop has made its deliveries. Each push order sends the exact quantities on its order wire to any requester of that cargo, in any quantity. It ignores all thresholds: depletion, fullness, manually-set per-item thresholds, and the "Enforce train fullness threshold when providing" setting.

Networks, allow lists, train capacity, and the delivery limits of both stations still apply. A requester receives at most the amount it is missing. The push phase does not touch cargo that the regular loop reserved for other requesters.

A push order ignores negative signals and the "Auto provide all" setting, so the order wire must carry the cargo you want to push. To push a station's whole inventory, wire the inventory to the order wire together with `Push`.

To push only above a certain quantity, use a decider combinator that passes cargo to the order wire once the station holds more than that.

Only requesters with explicit item or fluid requests receive pushed cargo. "All Items" orders, OR orders, and quality spread orders receive none.

:::info
For a trash station, wire the station's inventory to its order wire together with `Push` = 1. The station sends each item to any station requesting it, even when the amount falls below that station's thresholds.
:::

## Network Matching

In advanced mode, you may change how orders are matched to determine network overlap.

In addition to the default option, called `OR`, advanced mode offers an `AND` option.

When set to `AND` mode, a providing station must be on **ALL** of the networks of the requesting station in order to be considered a match. In other words, the requesting station's networks must be a subset of the providing station's networks.

This is distinct from the default `OR` mode where only one network intersection is required.

:::info
The requesting station **always** determines the network matching mode, as well as the set of networks which must be matched.
:::
