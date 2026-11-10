# BVL Assist v0.8.162

Improves Auto Spike flights that previously contacted the ball but hit the net or went out. The planner uses the actual locked airborne heading, refreshes flight selection early enough for tilt to settle, and evaluates ordinary native spike launches from predicted contact geometry with an eight-stud landing reserve. Quick anticipation uses an actual Set, a shared setter preview, or the private bot's native release geometry.

This release also includes the v159 selected-hitter contact-priority recovery fixes for difficult Normal receives. Experimental Auto Serve remains removed.

Validation passed 5,581 main checks, 62 preview runtime checks and O0/O1 compilation. The final private tests completed 12/12 native spikes across recorded Normal, Quick, Short and Pipe feeds, followed by 11/11 in the original authored bot setup. All 23 landed fully in bounds with no net, illegal or out result. These tests used the 6'8 / Bunnies / Steadfast / Atsumu build in PlaceVersion 90.

Moving opponents, ranked matches and other builds remain unverified. Native flights are estimates with baseline lift/speed terms; unsupported short-spike angles and budget-limited cases can still use an explicitly uncalibrated fallback. Successful in-bounds tests do not guarantee exact marker accuracy or every future contact.

Rerun the existing loader to update:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

Bundle: 808,749 bytes. SHA-256: `3C868DC616E6CBF508F15F18348A36D5EBA9EF7092AC9B58C2B2B8C577F65E9B`.
