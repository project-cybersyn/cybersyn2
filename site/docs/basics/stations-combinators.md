---
sidebar_position: 2
---

# Stations and the Cybersyn Combinator

A station is a train stop where Cybersyn can pick up or deliver goods. Stations are created by placing a Cybersyn combinator next to the desired train stop.

## Train limits

Cybersyn does its best to respect the built-in train limit value from Factorio, but there are a few important differences to note:

:::note

Cybersyn reserves train limit slots at both the provider and requester in advance when it schedules a delivery. This can cause a requester station to be blocked from trains even when the vanilla Factorio train limit would allow more.

This can feel very different (and more restricting) than vanilla Factorio, where the train limit counts trains pathing to that station only.

:::

:::warning

Changing the train limit dynamically will not have any impact on deliveries in flight to the station, even if that number exceeds the newly set limit.

Future deliveries will not be scheduled if they would put the total number of deliveries over the newly set limit, but currently scheduled deliveries must still be dealt with.

:::

:::danger

**Changing the train limit of a Cybersyn station to 0 will prevent Cybersyn's train routing from working and break the station, resulting in stuck trains. DO NOT decommission stations by setting their train limit to 0!**

:::
