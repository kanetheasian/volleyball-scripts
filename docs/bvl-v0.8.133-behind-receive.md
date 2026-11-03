# v0.8.133

Add diagonal glide approach routes for held dumps with a receive behind the setter. Existing native reach, jump power, movement timing, own-side, net and landing validation remain in place. Uncommitted airborne Spike selection checks stronger measured powers first; a settled pose refresh retains its selected power. When multiple powers are available, contact probes are bounded per power to leave time for a reliable lower-power fallback.

Validation: 4665 local assertions and Luau O0/O1 compilation passed. Mirrored geometry tests and a replay using current measured launch samples cover routes omitted by v132. Local replay is an approximation, not a full live match simulation.

A live route-only trial confirmed a gliding P3 Spike that crossed the net and was received by an opponent. This resolved the observed no-jump fallback for that attempt but was a weak shot. The final power-priority correction passed regression tests and startup readback; strong behind-receive Spike reliability remains under live validation.

Bundle SHA256: 4F600506495981705C0D13EAC28A4CB4421048DD0C1BEC77E9971DFFE6466BFD.
