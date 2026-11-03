# v0.8.135

Hold2 now forces a native Set at reachable contact using the selected play and hitter. It bypasses normal team/touch/consumed filters, court bounds, planned intercept and delivery-quality/hitter-arrival rejection. It does not substitute a different hitter. Selected play placement and best-effort delivery power are retained. Native Set hitbox geometry and action acceptance still determine contact; an already airborne player uses airborne Set. Release restores ordinary Auto Set behavior.

The direct contact path uses the actual Set box and forecasts horizontal movement without changing normal planner geometry. Native request acceptance and actual Set confirmation remain distinct.

Validation:4755 local assertions and O0/O1 compilation passed. Solo live native-bot testing produced12 confirmed Sets from12 feeds across the round, including center/angled receives, invalid eligibility metadata and a sideline Pipe case. Four contacts used the final build. Hitter/score success is separate: the long sideline Pipe deliveries did not reach their selected hitter under that play's power range. This is bot-lobby evidence, not ranked reliability proof. Test controls and user settings were restored, feeds stopped.

Bundle SHA256:8AB5944F0332A0D00D27B93A629D54A09DBE4C5C459D000CC930863A4627750C.
