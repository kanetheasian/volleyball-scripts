# BVL Assist v0.8.124

Held-B dumps use the native oriented Spike hitbox, distinguish recorded impact poses from swing-request poses, and account for measured client/server pose delay. Same-kit measured launch powers and contact delays inform selection. Preview Set upgrades and the accumulated normal-set recovery changes since v0.8.72 are included.

Published at the user's request from the exact live-tested 593431-byte bundle. SHA256: 167592E4C533AD8A2BECCB60A18212C26995D2572D5BEA78C73B1D3AE6F17B00. Local validation: 4383 assertions, 52 preview-runtime checks, and Luau compilation at O0/O1.

The final solo native-bot simulation covered 32 scenarios and 33 actual feeds: 19 gliding Spikes, 8 Set fallbacks, and 6 missed feeds including 3 empty jumps. All 27 contacts landed inside the opponent court. Coverage included net/attack/back-row lanes, sidelines, opposite-side receives, shanks and receive powers. One extra scheduled receive is included in the total. The user's current jump multiplier was 1.2 with tilt multiplication disabled; stamina settings were preserved.

Back-row gliding Spikes remain inconsistent, empty jumps remain, and incoming P6/P15 feeds had no contact. These are bot-court observations, not ranked or human-player reliability guarantees. Aggressive run-up and net-brush trials were rejected and are inactive in this build.

Rerun the existing loader to update. Publishing does not replace an already running script.
