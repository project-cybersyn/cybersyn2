---
sidebar_position: 5
---

# Allow Lists

A train will only visit a station if the train is on that station's **allow list**.

## Automatic allow lists

By default, Cybersyn will use an algorithm to attempt to determine what train shapes will fit at your station. This algorithm takes into account the presence of inserters, pumps, and loaders near the tracks at your station and infers valid train shapes.

The automatic algorithm allows a train at a station if it can infer that **the station can load or unload each of the train's wagons**.

## Manual allow lists

Sometimes the algorithm will not produce the desired behavior. In this case, it is possible to intervene manually by telling Cybersyn exactly which trains should be allowed at each station.

### Allowed layouts

Place a combinator in `Allowed Layouts` mode to select specific train layouts that can arrive at this stop. You may choose from any layout of any train that has been added to a Cybersyn train group.

The layouts are stored as an exact list of the rolling stock entities that make up the train, making them portable and blueprintable to the extent that trains with the same rolling stock in the same order are present in the destination save.

:::tip[Pro Tip]

If a layout containing both forward and reverse locomotives is added to the allow list, the reversed direction of the train is implicitly allowed as well. Make sure your bidirectional layouts are symmetrical or that your stations can support reversed trains!

:::

### Allowed groups

Place a combinator in `Allowed Groups` mode to specify exactly which train groups are allowed to visit the station.

Groups are stored by their group name, so note that when applying a blueprint of an `Allowed Groups` station across saves, trains will not be allowed unless the train groups in the destination save have exactly the same names as the corresponding groups in the source save.

## Allow all trains

In some cases you may wish to disable the allow list functionality altogether. By choosing the `Allow all trains` option, Cybersyn will route any available train to the station regardless of shape.

Note that network matching still applies, so you may use the network feature to control which trains can use the station even in `Allow all trains` mode.
