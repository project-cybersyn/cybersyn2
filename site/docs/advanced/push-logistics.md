---
sidebar_position: 5
---

# Push Logistics

Cybersyn stations producing items can be configured to **push** items in their inventory above a defined threshold. Pushed items are offered to ordinary consumer stations at higher priority, but in addition, can be moved to other stations designated as **sinks** and **dumps**.

A push station on the same network and channel as a dump can emulate the "purple/yellow chest" pattern of Factorio bot logistics.

:::note
Push logistics is an advanced feature that should only be used when needed. Some cases where push logistics can be helpful:

- For moving spoliable producs to their point-of-use rather than sitting in a buffer.
- For processes that can clog when things get full, e.g. petroleum gas production.
- For disposal of byproducts, e.g. stone from Vulcanus lava processing.
- For de-commisioning stations that are no longer wanted.

Push logistics has a performance impact. If you were to set all your stations to push, you would double the workload of Cybersyn's logistics thread. Most of your ordinary stations will not need and should not use push logistics.
:::

Cybersyn stations can actively push items to other stations designated as storage, rather than waiting for those items to be pulled by a specific request.

## Pushing from Stations

To push inventory away from a station, you must set a **push threshold** for each item to be pushed. Push thresholds can be set by placing a Cybersyn combinator in `Push thresholds` mode. Positive item and fluid signals fed to the input of this combinator will set the push threshold for the respective items.

Each item or fluid in the station's inventory (which must still be set in the ordinary way via the `Station` combinator) that is *above the push threshold* for that item or fluid will be offered for push logistics.

The amount available for push is equal to `total - threshold + 1`, with the exception that `threshold = 0` means it is not offered at all.

:::note
Setting a push threshold for an item to 1 will offer all available inventory for push.
:::

Items offered via push logistics are first offered to ordinary stations that may be requesting the item. If no ordinary requester can be matched, the system will attempt to match the item with a **sink**, followed by a **dump**.

## Sinking to Stations

To designate a station as an item sink, you must set a **sink threshold** for each item. Sink thresholds can be set by placing a Cybernetic combinator in `Sink thresholds` mode. Positive item and fluid signals fed to the input of this combinator will set the sink threshold for the respective items.

When the inventory of a particular item at a station is below its sink threshold, it will receive push deliveries of that item after all ordinary requests have been satisfied. If both an ordinary request and a sink threshold exist, the sink threshold will only have an effect if it is greater than the ordinary request.

:::note
Because deliveries in Cybersyn can be imprecise, even when using sink thresholds, you should still leave room in your buffers for overspill. Don't set sink thresholds exactly equal to buffer sizes.
:::

## Dumps

Dumps are special types of sink stations that will automatically sink **any and all** matching items or fluids. Only pushed cargo is eligible to be sent to dumps.

Dumps do not have individual filtering capabilities; in order to control which cargo can be directed to a dump, you must use a combination of **item channels** and **networks**. Dumps have the lowest possible priority of any station and orders will only be directed to a dump if they do not match anything else.

### Capacity

Dumps use a special `Capacity` combinator mode to specify whether they have room to hold a particular delivery.

Providing a positive value on the `All items` signal to the `Capacity` combinator sets the number of **available item slots** at the station. This is always measured in slots or stacks, never in individual items.

Providing a positive value on the `All fluids` signal sets the amount of **available fluid storage** at the station.

Deliveries will only be made to a station with a capacity combinator if the delivery size is beneath the given capacity.

:::note
Capacity combinators were designed for use with dumps, but they can actually be used with any station.
:::

## Notes

### Logistics Tiers and Priority

:::note
Logistics is done by tier in this order:

1) Pushers to ordinary requesters
2) Ordinary providers to ordinary requesters
3) Pushers to sinks
4) Pushers to dumps

Higher logistics tiers always take priority over lower, no matter the `Priority` value applied to the items in question. Priority values apply only within each tier.
:::
