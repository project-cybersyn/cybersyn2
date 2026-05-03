# Reset Procedure

Cybersyn 2 contains an internal mechanism to reset its internal state and
rebuild it from Factorio base world state. This procedure may be used to recover
from broken game states when no other options are available.

:::info
Although we try to avoid it, the developers may in extreme
cases require a reset as part of a version upgrade. Usually this will be
in instances where we need to change the structure of internal data storage.
:::

## How to Reset State

0. Record the version you are currently running (Git release or Mod Portal version). *If you are not changing versions, skip this step.*
1. **Back up your save.**
2. Disable Cybersyn logistics in mod settings and wait for all trains to return to depot and become idle.
3. Run `/cs2-shutdown`.
4. Confirm you see `Cybersyn 2 shutdown complete.`
5. Save the game to a new save file (do not overwrite your backup).
6. Exit the game and update to the release that requires a reset. *If you are not changing versions, skip this step.*
7. Load the save you made in step 5.
8. Run `/cs2-restart`.
9. Confirm you see `Cybersyn 2 restart complete.`
10. Re-enable Cybersyn logistics in mod settings.

At this point, your base should resume normal operation.

## If `/cs2-shutdown` Fails

Cybersyn can fail to shut down, printing a list of reasons why it failed. In this case, the
recommended action is to address the given list of reasons, then run `/cs2-shutdown` again.

If you find yourself unable to address the listed reasons, you may force a shutdown using `/cs2-shutdown force`.
This is recommended only as a last resort, as it may leave behind lingering bad game state.

If you previously shut down and did not restart yet, shutdown will also fail
until you run `/cs2-restart` (or use `force`).

## If `/cs2-restart` Fails

`/cs2-restart` requires shutdown data from a prior `/cs2-shutdown`. If no
shutdown was done in the current save state, restart will fail and you must run
shutdown first.

## Restoring from Backup

If anything goes wrong and you need to recover:

1. Install the exact version you recorded in step 0.
2. Restart Factorio.
3. Load your backup save.

