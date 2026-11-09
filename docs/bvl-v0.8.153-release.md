# BVL Assist v0.8.153

Normal sets to live players use a preferred attack band half a stud lower, matching the height trim used in the latest live-player session. The physical hitter center and reachable recovery floor are preserved. Tight bands clamp safely instead of being inverted by the reduction.

This is a small tuning release on the published v0.8.152 solver. It includes no experimental trajectory, jump-timing, or recovery changes from the ongoing investigation. Bot targets and Quick, Short, and Pipe retain their existing height selection.

## Validation and limits

All 5,436 main-suite checks, 55 integrated preview checks, and standalone O0/O1 compilation passed. Three additional checks cover the half-stud reduction, preserved physical reach, and narrow-band clamping.

The corresponding session tuning recorded a later batch of 18 server-confirmed jump Sets to monkaky: 13 produced spikes, four next contacted an Illegal boundary, and one next contacted the floor. The 13 spike contacts had 1.07-1.45-second set flight, with four front and nine rear contacts. Earlier in the session three attempts jumped without sending a Set request. These results do not establish ranked-match reliability or resolve the remaining missed-contact and rear-placement issues. Those issues remain under investigation.

## Download

Rerun the existing loader before the match to load this version. A script already running does not update itself.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

Bundle: `beyond_volleyball_assist.luau` (765,934 bytes).

SHA-256: `B648C5523C27E57620248ED3346B16C7BF85894DBB9FB588050E70A873E2FA3A`.
