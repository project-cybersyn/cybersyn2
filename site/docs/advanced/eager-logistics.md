---
sidebar_position: 3
---

# Eager Logistics

Cybersyn supports sending trains to providers in advance and holding them there until they are needed, optimizing away half of the ordinary delivery cycle at the expense of needing more trains. This mode of operation is known as **eager logistics**.

## Eager Provider Mode

By checking the `Eager provider` option in the Advanced section of the `Station` combinator, you will turn that station into an **eager provider**.

An eager provider can provide **exactly one item or fluid**, which must be given as a positive value at the input of the station combinator. If more than one item has a positive value, the station will be disabled and a warning issued. The value of the signal does not matter. Eager providers are always assumed to have an effectively infinite quantity of the designated resource available.

When in this mode and providing a valid item or fluid, **a number of trains equal to the train limit of the station will be reserved for the station**. When one of these trains finishes a delivery, it will return to the eager provider instead of depot.

The particular train waiting at the eager provider station will be considered to be **an implicit provider of its cargo**. This operates as if the train itself were a provider station with circuit input equal to the contents of its inventory. The train will wait at the eager provider to pick up product until a matching request for that product is found, at which point it will be dispatched to fill the order.

When one of these trains completes a delivery, it will return to the designated eager provider **even if its inventory is dirty**. Unlike ordinary pull logistics, dirty inventory is not considered a problem in an eager provider setup, as the train is to be reused to provide the same item again.

:::note

- An eager provider must be in "provide-only" mode. The option will be disabled unless this mode is set.

- Dynamically reducing the train limit of an eager provider does not immediately change the train set. Trains are only ejected after they have visited the provider and completed a subsequent delivery.

- If you want to destroy an eager provider, remove the signal advertising the provided resource. This will cause trains to be removed from the set as they visit the provider. As with all other Cybersyn stations, **dynamically reducing the train limit of an eager provider to 0 will break it.**

- Eager providers ignore all departure conditions except `Force-out signal`. If a train is forced out of an eager provider, it is ejected from the set of trains reserved for that provider and returned to depot.

:::
