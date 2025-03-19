---
sidebar_position: 4
---

# Item Channels

Cybersyn stations can partition items into 32 **channels** using bitmasks, only delivering items between two stations if the two stations share a channel for that item.

## Deliveries with Channels

When a station has a `Channels` combinator, an item will only be delivered to or from that station to another station that shares a channel for that item. Two stations share a channel for an item if the bitwise `AND` operation on the two stations' channel bitmask for that item is not zero.

## Assigning Item Channels

To assign channels to items at a station, add a Cybersyn combinator in `Channels` mode to your station. Each item or fluid signal sent to the input of this combinator will set the value of the signal as the channel bitmask for that item at that station.

## Channel Options

### Default Item Channels

The `Default item channels` option assigns a default channel bitmask to all items for which a channel signal is not provided at this station. By default this is `0`, meaning unspecified items will not be assigned any channels.

### Default Remote Channels

The `Default remote channels` option assigns at this station a default channel bitmask to **all items** coming from **all stations that don't have a `Channels` combinator**. This station will treat all items coming from unchanneled stations as being on the given channels. This can be used to allow a channeled station to continue to associate with unchanneled stations in a user-defined way.

By default this is `0`, meaning that this station will not exchange deliveries with unchanneled stations.
