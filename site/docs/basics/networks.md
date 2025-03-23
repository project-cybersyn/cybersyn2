---
sidebar_position: 4
---

# Networks

Deliveries can only be made between Cybersyn stations that share overlapping networks.

## Networks

Networks are defined by Factorio virtual signals. Combinators that interact with networks will have a default network setting in their GUI where you can assign a single static network to the combinator.

All combinators that accept networks can also be assigned multiple, dynamic networks by setting their default network to the "Each" virtual signal. In this mode, the combinator will treat all virtual signals fed into its input as network names, with the numerical values of those signals being treated as subnetwork masks.

:::danger[Warning]

Only **virtual** signals are acceptable network names. Selecting a non-virtual signal as a combinator's default network in GUI will raise an error. Sending a non-virtual signal to a combinator in "Each" network mode will not assign a network and will usually do something else instead.

:::

## Subnetworks

A stations subnetworks are defined by bitmasks associated to each network signal, with each bit representing one of the 32 subnetworks of a network. The bitmasks are assigned by providing a numerical value on the associated signal with the circuit network.

Two subnetworks overlap if the bitwise `AND` operation on their bits is not zero.

:::tip[Pro Tip]

Bitmasks are 32-bit signed twos-complement integers. A signal value of `-1` has all 32 bits set to 1 and therefore matches all possible subnetworks.

:::
