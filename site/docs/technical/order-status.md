# Order Status

This explains what each of the order statuses in the Node GUIs mean.

## Fulfilled

The dispatch loop believes this order is filled and no further train dispatches are needed. Note that this does not necessarily mean the inventory is physically present; some inventory may be on future incoming trains.

## No matching provider

There is no provider within the same topology and networks that can provide the requested cargo at the proper threshold.

## No vehicle

The resources are available, but no non-busy vehicle could be found to transport them.

## Requester capacity mismatch

The capacity limits of the stations involved do not match. This usually means that all trains with sufficient capacity have been disallowed due to not being on the allow list.

## Being fulfilled

A delivery for this order has recently been routed.

## Provider queue full

A provider, requester, and train were matched, but the provider's queue became full.

## Requester reached max deliveries

A provider, requester, and train were matched, but the requester exceeded the global max delivery setting.

## Late invalidation

A provider, requester, and train were matched, but a game state change invalidated the delivery between execution timeslices of the dispatch loop. There are several possibilities:

- The vehicle became invalid. (E.g., was destroyed etc.)
- One of the two nodes became invalid (e.g., train stop destroyed, combinators destroyed...)
- The vehicle has no fuel.
- The final generated manifest was empty.
