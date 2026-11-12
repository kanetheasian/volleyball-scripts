# BVL Assist v0.8.184

Close Normal backsets now prefer power 4 within 16 studs, one above the close front-set preference. Close Medium backsets allow at least 1.0 second of flight for a descending recovery with at least 1.8 studs of apex-to-contact drop; the old 1.1-second recovery floor could reject the extra power despite a good upper contact. The requested Medium profile remains preferred. The solver retains lower power when the stronger delivery cannot satisfy the loft, attack-height, court and player-power constraints. This addresses a captured power-2 backset that fell short and later power-3 deliveries that contacted the hitter too low.

Backsets use separate native range/arc, pitch and future-hand calibration instead of the front-set fit or the older backset velocity estimate. A backward native hand frame reverses the outgoing look; airborne and ground backsets keep independent launch models. Matching backset contact samples correct the future hand height and travel during glide. Samples remain scoped to the character and jump settings. Until enough matching samples exist, prediction retains the native-lag fallback.

A held but unaccepted close backset can upgrade to the stronger legal delivery when the incoming contact changes. A bounded extra-power search reserves up to 3 ms to check only the stronger power, so an exhausted general planner budget cannot silently skip the upgrade. A native startup longer than 0.3 seconds now refreshes power at the full activation window. Once the native Set is accepted, power and tilt remain locked while heading can track the remaining contact time for both front and back sets.

Validation: full regression suite passed; runtime 508 checks, bot contact/power 92 checks, armed front/back aim 40 checks, preview runtime 62 checks. The generated bundle compiles at O0 and O1. The final two isolated backsets both used power 4, contacted at world Y 20.406 and 20.418, and led to target Spikes clearing the net. Their native flight times were 1.133 seconds each. These checks use one stationary practice hitter with recorded contacts as calibration; new-character cold calibration, moving real hitters and ranked reliability remain unverified.

Rerun the existing loader to update. The menu version should show 0.8.184.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

