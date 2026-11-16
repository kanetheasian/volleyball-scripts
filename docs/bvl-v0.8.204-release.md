# BVL Assist v0.8.204

Extend the existing stronger close-backset search to live player targets. The prior condition ran this recovery only for authored bot hitboxes, allowing a weak retained live-player backset to bypass the P4 check. The solver now checks that same legal P4 alternative for a nearby live hitter before accepting a weaker backset. It uses the existing trajectory, Normal arc, player pace and arrival validators; if the stronger set cannot satisfy them, the original physically usable delivery remains available. Accepted commands are not replaced afterward. This is a conditional quality preference, not a forced minimum power.

Live evidence included a P1 SetBack with about 39.67 degrees of outgoing direction error followed by a Net contact. That demonstrates the weak/off-target report, but does not establish that the stronger P4 alternative would have been valid for that exact earlier contact or that this change fixes every aiming error.

Full regression passed, including 107 contact-height checks, with both live-player and bot targets exercising retained and recomputed backsets. O0/O1 compilation passed. The separately reported overhead no-contact failure has not repeated during the newly recorded jump attempts, so this release does not claim to fix that timing failure. A local read-only timing recorder was prepared for further reproduction.

Bundle: 904575 bytes. SHA-256: `017c984d1b67f1e6822c73214705b6f5475456f1bee756186e00c5baedd72c9e`.
