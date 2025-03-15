---
sidebar_position: 5
---

# Allow Lists

A train will only visit a station if the train is on that station's **allow list**.

## Automatic allow lists

By default, Cybersyn will use an algorithm to attempt to determine what train shapes will fit at your station. This algorithm takes into account the presence of inserters, pumps, and loaders near the tracks at your station and infers valid train shapes.

## Manual allow lists

Sometimes the algorithm will not produce the desired behavior. In this case, it is possible to intervene manually by telling Cybersyn exactly which trains should be allowed at each station.

### Allowed groups

Place a combinator in `Allowed Groups` mode to specify exactly which train groups are allowed to visit the station.

Note that when applying a blueprint of an `Allowed Groups` station across saves, trains will not be allowed unless the train groups in the destination save have exactly the same names as the corresponding groups in the source save.

## Allow all trains

In some cases you may wish to disable the allow list functionality altogether. By choosing the `Allow all trains` option, Cybersyn will route any available train to the station regardless of shape.

Note that network matching still applies, so you may use the network feature to control which trains can use the station even in `Allow all trains` mode.
