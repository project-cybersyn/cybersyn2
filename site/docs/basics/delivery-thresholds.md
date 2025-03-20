# Delivery Thresholds

A **delivery threshold** for a station is the minimum number of a particular item a train must be dropping off or picking up at that station in order to be dispatched.

Delivery thresholds are **per-item**. This means for multi-item stations, the delivery threshold applies separately to each individual product, not each train.

For items, delivery thresholds are interpreted as raw quantities unless `Use stack thresholds` is checked in the `Station` combinator, in which case they are interpreted as stacks.

## Setting Delivery Thresholds

### For all items and fluids

Providing the `Item threshold` or `Fluid threshold` signal to the `Station` combinator will set the delivery threshold for all items or fluids simultaneously.

### For particular products

Placing a combinator at the station set to `Delivery Thresholds` mode allows finer control over the thresholds. Each positive item or fluid signal input to the `Delivery Thresholds` combinator will set the delivery threshold for that particular product equal to the value of the signal.

### For particular directions

If the `Inbound` option is checked in the `Delivery Thresholds` combinator, the inputs will apply specifically to deliveries coming into this station, overriding the general value. If the `Outbound` option is checked, likewise but for outgoing deliveries. If both are checked, likewise for both.

In these modes, you can also supply the `Item threshold` and `Fluid threshold`
