# v0.8.131

Grounded Normal sets now arm near native reach entry for falling receives, using measured front/back contact delay to forecast the outgoing launch. Native state, facing, reach and selected hitter checks remain in place. The controller retains a validated later contact if the earlier candidate is unavailable, uncalibrated, lower or loses its existing loft. Jump, Quick and held-dump timing are unchanged.

Fix an aiming-line animation timer error when a visual created from a grounded player's replicated Spike flight is reused after that player jumps. Saved profile format is unchanged.

Validation: 4,648 local assertions passed, including 240 timing checks across both sides, front/back, multiple contact delays and unsuitable earlier contacts; Luau O0/O1 compilation passed. Passive ranked observation confirmed two early Normal sets, both hit by the selected teammate around 19 studs high and cleared the net. This is limited live evidence, not full scenario coverage; held dump misses remain under investigation.

Bundle SHA256: EDC8A497F9A541F4D0DF1ED152856C6CE77F0C159569280187BDDEBD41B1E8AE.
