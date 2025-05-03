---
sidebar_position: 2
---

# Stations and Combinators

A station is a train stop where Cybersyn can pick up or deliver goods. Stations are created by placing a cybernetic combinator next to the desired train stop.

## Cybernetic Combinator

The cybernetic combinator is the means by which you provide configuration and logistics information
to Cybersyn.

### Crafting

The cybernetic combinator is built from a recipe similar to other combinators.

TODO: screenshot

:::note
You must research the corresponding technology to unlock the ability to build the combinator.
:::

### Deploying

Once you've crafted a combinator, you can deploy it into the world. When holding a combinator, you
will see a yellow box around your cursor:

TODO: screenshot

This represents the radius that will be searched when binding the combinator to a stop or rail. You
must position the combinator so its target is within the yellow box.

### Configuring

### Controlling

Cybernetic combinators send and receive certain inputs and outputs via the circuit network. The mode
of the combinator dictates how these inputs or outputs are to be interpreted.

:::note
Cybersyn **requires** the circuit network. If you want to use Cybersyn to its full potential, you
should become familiar with it. This is by design; we will often refuse feature requests if the
feature can be implemented easily in circuits.
:::

## Stations

### Train limits

Cybersyn respects the native Factorio train limit value set on a stop, but due to limitations in the Factorio API, there are some caveats to be aware of:

:::warning

Sending a train outside the control of Cybersyn to a Cybersyn stop will cause Cybersyn to undercount
the train limit of that stop, possibly resulting in an over-limit situation.

:::

:::warning

Changing the train limit dynamically will not have any impact on deliveries in flight to the station, even if that number exceeds the newly set limit.

Future deliveries will not be scheduled if they would put the total number of deliveries over the newly set limit, but currently scheduled deliveries must still be dealt with.

:::

:::danger

**Changing the train limit of a Cybersyn station to 0 will prevent Cybersyn's train routing from working and break the station, resulting in stuck trains.**

Do not attempt to decommission a station by setting its limit to 0. Instead, disable all inventory input signals. This will prevent further deliveries to the station.

:::

### Factorio Priorities

:::danger

**Changing the Factorio priority of ANY station to a value other than 50 will break all Cybersyn deliveries on that surface.**

This is due to limitations in the Factorio API. At this time, Factorio priorities are outright incompatible with Cybersyn and may not be used.

:::
