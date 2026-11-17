# BVL Assist v0.8.205

Auto Set now tracks received balls farther beyond the sidelines and baseline. Court association uses horizontal distance beyond the court rectangle instead of the old center-based cutoff. Ranked lineup membership takes priority; an active recovery retains its court, and walking through the gap between practice courts no longer changes courts halfway through a chase.

Outward flights can use up to six seconds of forecast, bounded by estimated remaining flight. Ordinary in-court passes and dumps retain the existing 2.8-second horizon. Recovery jobs retain enough lifetime for the longer interception. Advanced settings expose the forecast limit (2.8-6 seconds) and distance beyond court bounds (default 100 studs, range 20-180). Native movement, contact volume, selected-hitter targeting and delivery checks remain in force.

Validation: full regression passed, including 15 new outside-recovery checks, O0/O1 compilation and 62 preview runtime checks. The candidate loaded in the private server with no reported assist errors. Two isolated right-shank feeds and two receives originating at Z=87 each produced a confirmed native Set and a contact from the selected temporary hitter bot (4/4). These are private-server bot results, not ranked or human-hitter reliability proof. The left shank was physically unreachable from the common starting spot at measured movement speed and was not counted as a successful save. Further live tests were stopped at the user's request. The user's five example bots and original settings were preserved; the temporary hitter was removed.

Bundle: 907264 bytes. SHA-256: `540b6f605307c50a4259357c65f0b7afba8d09fa4a91d0c34f4315edce2df54c`.
