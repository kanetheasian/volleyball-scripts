# BVL Assist v0.8.152

Auto Set now searches for a reachable selected-hitter recovery when the preferred floating set cannot be delivered. Auto prefers a safe jump set and uses a ground save when the remaining flight cannot accommodate arrival, native jump charge, and airborne Set startup.

## Changes

- Added recovery searches across every legal power, up to the player's native maximum. Recovery can use a quicker or longer flight instead of being rejected by Normal's comfortable speed and timing limits.
- Preserved the selected spiker as the recovery target. Recovery does not silently substitute a dump.
- Corrected shallow-jump planning so a low ball cannot shorten the minimum airborne preparation needed by the native Set action. Arrival margin is checked during candidate search, allowing a later safe jump before ground fallback.
- Ground saves use the reachable portion of the native Set sphere, including lower contacts, and continue approaching while the outgoing recovery is being solved.
- Added native ground-launch prediction and separate ground/air calibration banks.
- Includes the preceding local Auto Set repairs: multiple selected-player persistence, shared preview/planning fixes, upper-front contact preference, observed glide handling, and native launch geometry.

## Validation and limits

The final controlled private-lobby batch made 15 server-confirmed Set contacts from 15 tracked receives. Thirteen reached the selected bot hitter; two ground recoveries hit the net first. The ordinary nearby case passed 3/3 with clearly airborne contacts in front of the hitter. Auto used ground contacts for all four late low-ball feeds, while the backrow case retained jump attempts.

Difficult recoveries still include rear placement, and one early backrow contact had a ground-height server pose despite a jump request. This release does not guarantee every receive is physically recoverable, perfect upper-front placement, or universal real-player reliability.

Offline validation: 5,433 main-suite checks, 55 integrated preview checks, and standalone Luau compilation at O0 and O1 passed.

## Download

Keep the existing loader and rerun it to fetch this update. A script already running does not update itself.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

Bundle: `beyond_volleyball_assist.luau` (765,313 bytes).

SHA-256: `2AA0BF2AD42C1F6ECBFEE4037A252A7DE84DFCEABF0444892596AFE9A6E5FE79`.
