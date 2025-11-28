---
sidebar_position: 4
---

# Networks and Priority

## Networks

Deliveries can only be made between a providing order and a requesting order if those orders are on matching **networks**.

Up until this point, we have been relying on the fact that orders come out of the box set to the default "A" network. This means that all orders we have created so far have automatically been all mutually visible to each other. Now you will learn how to change that behavior.

### Networks and Network Masks

A **network** is defined by two things:

1) A Factorio virtual signal name
2) A "1" bit somewhere in the value of that signal, interpreted as a 32-bit signed integer bitmask

It's convenient to write a network as a signal name followed by the bit number that's set in the mask. For example, if we say a station is on network "A1" we mean that it's on the network with virtual signal A with the value of 1 (first bit set). If we say a station is on network "C4" we mean it's on the network with signal C and value 8 (fourth bit set). If we say the station is on networks A1 and A2, we mean the signal A with a value of 3 (bits 1 and 2 set).

When a Station combinator is newly placed, its default order is initialized to be on networks A1 through A32 (signal A with a value of -1).
:::info
The value of -1, which is the default mask, has all bits set. You can change the default network mask from -1 to another value in Cybersyn's mod settings.
:::

### Setting Networks

To change the networks of an order, you have 3 options:

#### Static Network

In the *Order Settings* section of the Station combinator's settings, you may choose a virtual signal for the **Item Network** setting field. This will place the station on the networks corresponding to that virtual signal and the bitmask given by the default value in the Settings.

#### Single Signal with Bitmask

Using the *order wire*, you may send a value on the virtual signal you set in the **Item Network** field. If you do so, that value will be used as the bit mask for the networks, overriding the default from mod settings.

#### Multiple Signals, Multiple Bitmasks

For complete versatility in assigning networks, you can set the **Item Network** field in the settings to the **Each virtual signal**. If you do so, ALL virtual signals sent on the *order wire* (except for the Cybersyn control signals) will be interpreted as networks, with each mask corresponding to the value of the signal.

With this approach, you can assign any order to any set of networks.

### Network Matching

Cybersyn will only route deliveries between matching orders. Two orders match **only if they share at least one network**. This means:

1) They must share at least one common virtual signal network input.
2) The Bitwise-AND of at least one pair of those common signals must be nonzero. (They share at least one bit.)

## Priority

You can obtain control of the order in which orders are serviced by setting a **priority** value on the orders. Priority values are set by providing the Cybersyn **Priority** signal on the *order wire*. Higher numbers represent higher priority (serviced first) and the numbers may be negative. The default priority for all orders when a signal is not provided is 0.

:::info
You may also send a Priority signal on the *primary wire*. Doing so simultaneously sets the default priority for all orders at the station. Signals sent per-order will override this default.
:::

### Priorities are Per-Order

Priorities apply at the level of orders, not individual items.

:::note
**Cybersyn 1 Note**: This is totally different from CS1, where priorities only applied per item.
:::

This means, for example, that a requesting order for copper ore at 300 priority will be serviced before a requesting order for iron ore at 100 priority. You must plan your use of priorities with this in mind.

:::info
This system gives fine control over which resources get trains first in times of train shortage. For example, if you feed nuclear plants with water trains, setting these water requesters to a high priority value ensures your plants are fed with water first even when you run out of fluid trains.
:::

### Factorio Priorities

Do not attempt to use Factorio priorities to change Cybersyn behavior. You must use the Priority signal provided by Cybersyn.

:::danger

**Changing the Factorio priority of ANY station to a value other than 50 will break all Cybersyn deliveries on that surface.**

This is due to limitations in the Factorio API. At this time, Factorio priorities are outright incompatible with Cybersyn and may not be used.

:::
