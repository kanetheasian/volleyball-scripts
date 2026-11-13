# BVL Assist v0.8.195

The default numeric jump-speed factor is now 1.25 instead of 2. The Movement Advanced label matches the new default. Existing saved profile values remain explicit overrides; the connected user's current factor was set to 1.25 at their request. The existing enable toggle and 1–4 range are retained.

The user reported low sets from a Receive bot at (-18, 3, 39), P2, targeting the Spike bot at (18, 14, 3), then confirmed that setting was working again. One controlled v194 observation (ball 368) confirmed a native Set followed by the intended bot Spike at 19.3758 studs. No Auto Set arc, rescue, power or timing algorithm changes were made in v195.

Full regression passed, including 652 runtime checks and the updated default timing expectation (native 0.4 seconds divided by 1.25 gives 0.32 seconds). Bundle compilation passed at O0 (773,352 bytes) and O1 (731,672 bytes). The local v195 reload preserved the user's complete freshly captured configuration, including their enabled jump-speed toggle, and both bots' pivots and attributes. Current factor was 1.25, and runtime errors were empty. No additional balls were generated after the user's correction.

Rerun the existing loader to fetch this version; a running script does not update itself. The connected client was already running this tested build before publication.

Bundle: 892,477 bytes. SHA-256: `468e8e6499008bbd56568243accaa4d233dc11d3cec5e290dfc90594f488d46c`.
