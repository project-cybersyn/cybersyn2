# Logistics Algorithm

## Terms

- **Node**: A place where items can be picked up and/or dropped off, e.g. a train stop.
- **Topology**: A set of nodes completely isolated from the nodes in other topologies. Nodes within the same topology may or may not be able to deliver to each other, but nodes in separate topologies *absolutely cannot*. Example: two different surfaces are two different topologies where trains are concerned.
- **Network**: A subset of the nodes of a topology.
- **Inventory**: The kinds and quantities of items available to be picked up, or desired to be dropped off, at a node. Usually each node has its own inventory, but some nodes may also share common inventory between them.
- **Vehicle**: Something that can pick up and drop off certain products at certain nodes.
- **Producer**: A node from whence items are to be picked up.
- **Consumer**: A node to whence items are to be dropped off.
- **Product**: an item or a fluid in an inventory or on a vehicle
- **Provider**: a **producer** that offers its items only to **pullers**
- **Pusher**: a **producer** that offers its items to any **consumer**
- **Puller**: a **consumer** that takes items from any **producer**
- **Sink**: a **consumer** that takes items only from **pushers**
- **Dump**: a **sink** that will take any product matching its channels.

## Assumptions

- When a variable is out of Cybersyn's scope, we will either avoid predicting the future value of that variable, or if we must do so, we will make the maximally pessimistic prediction.
	- e.g. if a station is below its delivery threshold for a product, since the station's production line is not within Cybersyn's scope, we will assume it is defunct and will *never* reach that threshold for logistics purposes.

- When a variable *is* in Cybersyn's scope, we will predict its future value as optimistically as possible.
	- e.g. if the same station has an inbound delivery of the same product that would put it over threshold, we assume optimistically that the train will get there and so we treat the station as over threshold.
	- we may not always be able to be fully optimistic, e.g. when sinking cargo to a station we can't assume a train that would've removed product would get there in time

## The Algorithm

- For each topology `T`:
	1. **Reset Phase**
		- Set `T.Providers`, `T.Pushers`, `T.Pullers`, `T.Sinks`, `T.Dumps`, `T.SeenItems` to empty structures
		- Set `T.AllocationQueue` to an empty queue
		- Generally clear out any other temp state
	1. **Poll Phase** For each node `N` in `T`:
		- Read all input combinator signals
		- Compute `N.PredictedInventory` from combinator signals + known future deliveries
		- Compute other relevant node logistic state (e.g. `N.*_delivery_threshold`...) from polled combinator data
		- If `N` is allowed to produce:
			- For each product `I` with `(n = N.Inventory[I]) > 0`:
				- If `n > N.outbound_delivery_threshold[I]`
					* Add `N` to `T.Providers[I]`
					* Add `I` to `T.SeenItems`
					- If `n` > `N.push_threshold[I]`
						* Add `N` to `T.Pushers[I]`
		- If `N` is allowed to consume:
			- For each product `I` with inventory `(n = N.Inventory[I]) < 0`:
				- If `-n > N.inbound_delivery_threshold[I]`
					* Add `N` to `T.Pullers[I]`
					* Add `I` to `T.SeenItems`
			- For each product `I` with *inflow* inventory `(l = N.InflowInventory[I]) > 0`
				> NOTE: we don't want to risk overflowing storage/stuck train, so we have to
				> compute an inventory as if no outflow was happening if we want this feature.
				- If `n < N.sink_threshold[I]`
					* Add `N` to `T.Sinks[I]`
					* Add `I` to `T.SeenItems`
			- If `N` is designated a dump:
				- Add `N` to `T.Dumps`
	1. **Allocation Phase** For each product `I` in `random_shuffle(T.SeenItems)`:
		> Throughout the allocation phase, `alloc(producer, consumer, item, qty)` means:
		> - Create an allocation object storing that data on the head of the allocation queue
		> - Deduct `qty` of `item` from the producer's predicted inventory
		> - Add `qty` of `item` to the consumer's predicted inventory
		1. **Pull**
			- For each group `Pullers<I,p>` in `descending_prio_groups(T.Pullers[I])`:
				- For each node `Puller<I>` in `sort_by_last_serviced(Pullers<I,p>)`
					1. **Pull from Pushers**
						- For each group `Pushers<I,p>` in `descending_prio_groups(T.Pushers[I])`
							- For each node `Pusher<I>` in `distance_and_busy_sort(Pushers<I,p>)`
								- If `Pusher<I>.Inventory[I] > Puller<I>.inbound_delivery_threshold[I]`
									- *Allocate:* `alloc(Pusher<I>, Puller<I>, I, max possible amt)`
									- *Optimize:* If `Puller<I>` needs no more `I`, unwind this loop. If `Pusher<I>`'s `I` is below threshold, remove it from `T.Pushers[I]`
					1. **Pull from Providers**
		1. **Push** For each node `N` in `sort(T.Pushers[I], N.Priority[I], descending)`:
			1. **Push to Sinks**
			1. **Push to Dumps**
	1. **Delivery Phase**
		1. Enumerate available trains
