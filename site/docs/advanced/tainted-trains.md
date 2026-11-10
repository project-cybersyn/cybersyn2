---
sidebar_position: 4
---

# Tainted Trains

Cybersyn 2 marks a train as **tainted** if a delivery completes or fails while
the train still has cargo aboard. This prevents leftover cargo from being
silently carried into a later delivery.

## What happens to a tainted train?

- Cybersyn 2 will not assign the train another delivery while it is tainted.
- A **Tainted train** alert appears and remains until the taint is cleared.
- The train's status is shown in its Cybersyn train window, where you can clear
  the taint manually.

## Clearing taint

By default, Cybersyn 2 automatically clears taint once the train is empty. This
is controlled by the **Auto-clear taint from empty trains** mod
setting. Disable it if you want to inspect or handle leftover cargo before
making the train available again.

You can also clear taint manually from the train's Cybersyn window, even if it
still has cargo. Do this only after checking that the remaining cargo is safe
to take on another delivery.
