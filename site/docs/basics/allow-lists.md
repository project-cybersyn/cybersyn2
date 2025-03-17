---
sidebar_position: 5
---

# Allow Lists

A train will only visit a station if the train is on that station's **allow list**.

## Automatic allow lists

By default, Cybersyn will use an algorithm to attempt to determine what train shapes can be serviced by your stations. This algorithm takes into account the presence of inserters, pumps, and loaders near the tracks at your station and infers valid train shapes.

The automatic algorithm allows a train at a station if it can infer that **the station can load or unload each of the train's wagons**.

:::warning

The automatic allow list algorithm does not support:

- Trains with more than 32 carriages.
- Loading equipment entities that are not `inserter`, `pump`, `loader`, or `loader-1x1`. (Unless added by another mod through the Cybersyn API.)
- Modified wagons that are not 6 tiles long or have a gap between wagons other than 1 tile.

In those cases, another allow list option must be used.

:::

### Automatic allow list options

By placing a Cybersyn combinator in `Allow List` mode, you can apply the following options to the automatic allow list:

#### Strict Mode

Strict mode imposes the additional condition that **every wagon slot that has equipment in it must match with a wagon on the train**. This means that trains that are "shorter" than the full set of loading equipment will no longer be allowed at the station.

#### Bidirectional mode

In bidirectional mode, trains will only be allowed if they have both forward and reverse locomotives. This can be used for stations that are at the terminus of a rail line.

## Manual allow lists

Sometimes the automatic allow list will not produce the desired behavior. In this case, it is possible to intervene manually by telling Cybersyn exactly which trains should be allowed at each station.

### Allowed layouts

Place a combinator in `Allowed Layouts` mode to select specific train layouts that can arrive at this stop. You may choose from any layout of any train that has been added to a Cybersyn train group.

The layouts are stored as an exact list of the rolling stock entities that make up the train, making them portable and blueprintable to the extent that trains with the same rolling stock in the same order are present in the destination save.

:::tip

If a layout containing both forward and reverse locomotives is added to the allow list, the reversed direction of the train is implicitly allowed as well. Make sure your bidirectional layouts are symmetrical or that your stations can support reversed trains!

:::

### Allowed groups

Place a combinator in `Allowed Groups` mode to specify exactly which train groups are allowed to visit the station.

Groups are stored by their group name, so note that when applying a blueprint of an `Allowed Groups` station across saves, trains will not be allowed unless the train groups in the destination save have exactly the same names as the corresponding groups in the source save.

## Allow all trains

In some cases you may wish to disable the allow list functionality altogether. By choosing the `Allow all trains` option, Cybersyn will route any available train to the station regardless of shape.

Note that network matching still applies, so you may use the network feature to control which trains can use the station even in `Allow all trains` mode.
