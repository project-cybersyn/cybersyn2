Yes. Several structural changes look promising without changing matching semantics.

**Highest Value**

1. **Exact cargo inverted index**

Build `providers_by_cargo[key]` during polling and enumerate only the union of posting lists for ordinary requester needs.

This changes candidate generation from:

$$
O(P \cdot R)
$$

to approximately:

$$
O\left(\sum_{key\in R}|\text{providers\_by\_cargo}[key]|\right)
$$

It also avoids node lookups, queue checks, network matching, plugin calls, and satisfaction work for disjoint providers. This remains the strongest option for broad providers and requesters.

Use generation marks to deduplicate providers appearing under several requested keys. Keep exotic orders on the current full scan.

2. **Hoist requester state out of the provider loop**

The same requester node is currently fetched for every provider in `logistics.lua:290`.

Resolve and validate it once in `loop_requesters`, then retain it for the provider scan. This removes $P$ repeated node lookups per requester and simplifies the inner loop.

The requester’s queue/delivery state still needs revalidation where asynchronous behavior requires it.

3. **Precompute match scores once**

The sort comparator repeatedly calls `match_score` in [logistics.lua](mods/cybersyn2/scripts/tasks/dispatch-loop/logistics.lua#L421). Sorting $M$ matches invokes it approximately $O(M\log M)$ times, twice per comparison.

`match_score` performs:

- Entity validity checks.
- Distance calculation.
- Capacity normalization.
- Several field reads.

Compute and store the score when each match is created, or once in a linear pre-sort pass. The comparator then compares priority and scalar score only.

This is a low-risk, likely meaningful win whenever requesters have many matches.

4. **Lazy match ordering instead of sorting everything**

The algorithm often routes through only a small prefix of the sorted matches. A binary heap can:

- Build in $O(M)$.
- Return each next-best match in $O(\log M)$.
- Avoid fully sorting unused matches.

This changes ordering cost from $O(M\log M)$ to:

$$
O(M+K\log M)
$$

where $K$ is the number of matches actually attempted.

It must preserve priority as the primary key and score as the secondary key. This is worthwhile only if profiling shows $K\ll M$; otherwise precomputed-score sorting is simpler.

**Satisfaction And Allocation**

5. **Allocate result tables lazily**

`satisfy_needs` allocates empty `fluids` and `items` tables before knowing whether anything matches (`order.lua:950`).

Create each table only on the first qualifying cargo. This directly reduces garbage generation for rejected candidates.

The same principle applies to exotic-order reducers, although those require more careful restructuring.

6. **Count during existing loops**

Several loops are immediately followed by `table_size` solely for workload accounting, causing a second traversal. For example, explicit needs are scanned and then counted again in `order.lua:950`.

Increment a counter in the original loop and report it afterward. This preserves workload accounting while removing repeated hash-table traversal.

7. **Accumulate item stack totals during satisfaction**

Explicit item matching builds `items`, then scans it again to calculate `total_stacks` around `order.lua:1080`.

For ordinary providers:

- Accumulate total stacks when inserting an item.
- When `provide_single_item` is active, track the maximum item during that same loop.

This removes another traversal. Exotic order paths may need separate handling because their stack budgets mutate while scanning.

8. **Fuse failed satisfaction with reservation calculation**

When satisfaction fails before any match is found, the code scans needs again in `reserve_provider_needs`.

Both operations calculate essentially the same provider availability:

```text
inventory - outflow
provide cap - outflow
requested quantity
```

A combined operation could return:

- A satisfaction, or
- Quantities eligible for reservation.

This could remove one complete needs scan for failed candidates. It is higher risk because reservation mutates shared outflow and must preserve the current provider-ordering behavior exactly.

**Train Selection**

9. **Index trains by layout**

Allowlist checks are exact layout-ID table lookups (`base.lua:97`). Group trains by `layout_id` during `enum_trains`.

For a provider/requester pair:

- Intersect their allowed layout sets.
- Scan trains only in permitted layout groups.
- If either stop allows all layouts, use the other side’s set.
- If both allow all layouts, retain the full train list.

This can substantially reduce train scans for restrictive allowlists. Dynamic availability and reachability callbacks must still run for every candidate train.

10. **Cache immutable train scoring inputs**

During one logistics cycle, these are generally stable:

- Layout ID.
- Item slot capacity.
- Fluid capacity.
- Normalized total capacity.
- Home surface.

Precompute them beside `self.trains`. `train_score` then avoids repeated normalization and object-field traversal.

Do not cache positive availability indefinitely: the thread yields and trains can become unavailable asynchronously. The existing permanent negative marking after observed unavailability is safer.

11. **Capacity rejection before reachability plugins**

The code currently has a TODO for literal zero-movement rejection after plugin checks (`logistics.lua:637`).

A cheap exact test:

```text
satisfaction has items and train item capacity > 0
or satisfaction has fluid and train fluid capacity > 0
```

can reject incapable trains before remote reachability callbacks and distance scoring. This is especially useful in mixed cargo/fluid fleets.

**Polling And State**

12. **Maintain topology node membership incrementally**

`enum_nodes` scans all global nodes and tests topology membership every cycle. The file already marks this as a hotspot.

Maintain a node list/set on each topology through node creation, destruction, and topology-change events. Enumeration then becomes proportional to topology size rather than global node count.

This is structurally valuable for games with many separate topologies, but lifecycle correctness is more involved than the logistics-local changes.

13. **Separate static provider classification from dynamic inventory polling**

Order cargo/network configuration changes less frequently than inventory quantities. Provider keys and network sets could be indexed only when order configuration changes, while each poll updates quantities and active eligibility.

This avoids rebuilding structural indexes every logistics cycle. It requires reliable dirty categories, so I would first build transient indexes and profile their construction cost.

**Changes I Would Avoid**

- **Satisfaction memoization:** inventory, inflow, outflow, needs, and reservations mutate throughout the yielded loop. Correct invalidation is likely more expensive and fragile than recomputation.
- **Caching queue-full state across the logistics phase:** it can change asynchronously and also changes as this thread creates deliveries.
- **Caching positive train availability:** same as above.
- **Pooling temporary Lua tables:** manual pools retain memory and often increase complexity without outperforming Lua’s allocator/GC for small tables.
- **Approximate candidate rejection with false negatives:** silently missing a valid delivery is not acceptable.

**Suggested Order**

1. Precompute match scores.
2. Hoist requester-node lookup.
3. Make `satisfy_needs` allocation-lazy and single-pass where practical.
4. Add exact cargo inverted indexing.
5. Add zero-capacity train rejection.
6. Profile train layout indexing.
7. Consider incremental topology membership only if node enumeration remains material.

The first three are relatively contained. The inverted index likely gives the largest asymptotic improvement, while the satisfaction changes should reduce allocation pressure and GC even when most providers genuinely overlap.
