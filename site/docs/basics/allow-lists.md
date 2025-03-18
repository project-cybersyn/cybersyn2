---
sidebar_position: 5
---

# Allow Lists

A train will only visit a station if the train is on that station's **allow list**. The allow list is a list of train layouts and train groups that are permitted to use the station.

## The default allow list

By default, Cybersyn will use an algorithm to attempt to determine what trains can be serviced by your stations. This algorithm takes into account the presence of inserters, pumps, and loaders near the tracks at your station and infers valid train shapes.

This algorithm will allow a train at a station if it can infer that **the station can load or unload each of the train's wagons**.

:::warning

The automatic algorithm does not support:

- Trains with more than 32 carriages.
- Loading equipment entities that are not `inserter`, `pump`, `loader`, or `loader-1x1`. (Unless added by another mod through the Cybersyn API.)
- Modified wagons that are not 6 tiles long or have a gap between wagons other than 1 tile.

In those cases, another allow list option must be used.

:::

## Changing the behavior of the allow list

The automatic algorithm works for the most common and straightforward logistics setups, but in certain cases, it may not behave the way you want it to. In those cases, you may place an additional Cybersyn combinator in `Allow list` mode. This will give you several options for customizing the behavior of the allow list.

### Automatic algorithm options

When the `Allow list` combinator is in the `Auto` allow list mode, your station's allow list will be computed by the above algorithm, but you can provide some additional inputs to tweak the behavior:

#### Strict allow list

Strict mode imposes the additional condition that **each station slot with loading equipment must be occupied by a train car**. This means that trains that are "shorter" than the full set of loading equipment will no longer be allowed at the station.

#### Bidirectional trains only

If enabled, trains will only be allowed if they have both forward and reverse locomotives. This can be used for stations that are at the terminus of a rail line.

### Manually allow specific layouts

In `Layout` mode you can manually select specific train layouts that can arrive at this stop. You may choose from any layout of any train that has been added to a Cybersyn train group.

The layouts are stored as an exact list of the rolling stock entities that make up the train, making them portable and blueprintable to the extent that trains with the same rolling stock in the same order are present in the destination save.

:::tip

If a layout containing both forward and reverse locomotives is added to the allow list, the reversed direction of the train is implicitly allowed as well. Make sure your bidirectional layouts are symmetrical or that your stations can support reversed trains!

:::

### Manually allow specific train groups

In `Group` mode you can specify exactly which train groups are allowed to visit the station.

:::note

Groups are stored by their group name. When applying a blueprint of a `Group` combinator across saves, trains will not be allowed unless the train groups in the destination save have exactly the same names as the corresponding groups in the source save.

:::

### Allow all trains

In some cases you may wish to disable the allow list functionality altogether. By choosing the `All` allow list mode, Cybersyn will route any available train to the station regardless of shape.

:::note

All trains really means all trains. If you need control over which trains arrive but none of the above modes are suitable, you will need to use the Networks feature in addition to the `All` mode to control which trains can arrive.

:::
