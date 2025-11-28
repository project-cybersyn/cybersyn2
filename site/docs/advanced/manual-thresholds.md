# Manual Delivery Sizes

It is possible to manually set the delivery sizes for a requesting station on a per-item basis. When manual delivery sizes are set, inbound deliveries to the given station for the given item must exceed the given threshold in order to be routed.

To set manual delivery sizes, construct a combinator in **Delivery size** mode. Positive cargo signals coming into this combinator will be interpreted as minimum delivery sizes for the given items. Delivery sizes are interpreted in stacks by default; a setting in the combinator will allow you to interpret them as units instead.

You may send an **All Fluids** signal to this combinator to set the threshold for all fluids simultaneously.

You may send an **All Items** signal to this combinator to set the threshold for all items simultaneously. **This value is always interpreted in stacks, regardless of the setting**.

## Notes on Manual Delivery Sizes

The use of manual delivery sizes is discouraged, and we strongly suggest learning to use automatic thresholds. Manual sizes exist only as an escape valve for certain otherwise unfixable scenarios.

As such, there are many caveats to be aware of when using manual sizes:

:::info
- Delivery sizes only apply to requests at requesting stations. There is no such thing as a "provide threshold."

- There are no guard rails on this feature; if you set a threshold that makes a request impossible to deliver it won't be delivered.

- When using manual delivery sizes with multi-item orders, all items in the order must meet their respective manual thresholds in order to be delivered.

- Manual delivery sizes are **completely ignored** for exotic orders and cannot be used in such cases. (Quality spread, OR orders, ALL orders)

- Manual delivery sizes defeat many other features of the logistics algorithm when used; for instance, starvation prevention does not apply to items for which manual thresholds are specified.
:::

## General Warning on Thresholds

:::warning
- **All thresholds in Cybersyn, including manual thresholds, are documented purely as hints, are not guaranteed to be honored, and may be ignored by the algorithm at its whim.**
:::
