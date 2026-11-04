# v0.8.138

Normal sets now prefer a slower descending arc at comparable attack height. Preferred tempo increases from 1.25 to 1.4 seconds; a longer loft can outrank a faster shot when the predicted height trade is no more than 0.75 studs. The only playable faster recovery remains available. Held-2 power selection uses the same soft pace preference without blocking its immediate Set behavior. These are forecast preferences, not guaranteed human contact times.

This release also includes the v0.8.137 updates:
- Normal Auto Set consumes an incoming revision only after confirmed Set contact, rather than native action acceptance.
- Positioning can begin while selected-hitter delivery search is still running. Preparation grants no hit permission and preserves team/touch/manual-input rules.
- A Visuals toggle shows confirmed spike-contact height above the court floor as small text for three seconds.

Selected hitter/play behavior, held-B eight-direction dumps and rotation cleanup remain included. Existing profiles retain their settings and gain the spike-height toggle's default.

Validation: 4,893 local assertions and O0/O1 compilation passed. v0.8.137 natural ranked observations included two confirmed selected-hitter sets followed by net-clearing spikes, plus unconfirmed requests recorded separately. The spike-height label was observed in-game. The original close-receive miss was not reproduced. v0.8.138 loaded successfully with settings preserved, but server changes prevented post-update pacing validation; no live speed improvement or universal ranked reliability is claimed.

Bundle: 633,342 bytes.
SHA256: 2D5E9C55F58BC7888939334E8382A72B61BA6C995BAE7B235F6A85D1BF5ECBBF.
