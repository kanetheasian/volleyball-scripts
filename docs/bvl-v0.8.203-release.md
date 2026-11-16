# BVL Assist v0.8.203

Fix two outside-court planning restrictions. The final playable-set recovery uses a horizontal pace ceiling based on contact-to-hitter distance divided by 0.85 seconds, bounded to 30–65 studs/second, rather than rejecting every recovery above 30. Native legal power, descending loft, 0.45–2.8-second flight, same-side in-court target and hitter-arrival checks remain in effect. Ordinary preferred Normal delivery keeps its existing pace constraints.

Sideline recovery now retains a physically reachable back intercept when the preferred delivery search consumes the frame budget. If there is budget, a validated front delivery still wins over an unresolved back delivery. A failed front search no longer discards the pending back intercept. Retained physical reach is not mislabeled as solved delivery.

Live v202 history showed unarmed ranked ball 22 with planned contact (2.9756,17.8379,61.8681), beyond the end line, ending with no usable hitter delivery. A read-only calculation using that contact produced a P14 delivery at about 43.76 horizontal studs/second and 1.338 seconds of flight only after lifting the old pace predicate. This supports the pace-cap fix but does not prove every missed outside receive has the same cause.

Full regression passed, including 77 set-lane and 55 match-recovery checks. Added regressions cover budget-expired sideline retention, failed front search, validated-front preference, and a legal longer-range playable recovery. O0/O1 compilation passed. Loaded between points preserving configuration. Actual outside-court recovery after the patch remains to be live-verified.

Bundle: 904556 bytes. SHA-256: `2df4b3fc87ee7535c5b01b2b3278c42df0b72b024951463b72fd24b1c2b300c1`.
