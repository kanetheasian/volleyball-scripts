# BVL Assist v0.8.154

Fixes a runtime error that prevented some ground Set requests from reaching the native state machine.

When a ground request explicitly passed `air=false`, the glide probe evaluated to boolean false. A nil-only guard then tried to read its `Velocity` field, raising `attempt to index boolean with 'Velocity'` before the Set was sent. The guard now requires an actual truthy velocity object and otherwise records `glide=false`. Ground Set and SetBack, legacy nil-air calls, and airborne calls keep their native request routes.

This release retains v0.8.153's half-stud lower Normal target. It adds no experimental trajectory or timing changes.

## Validation and limits

The new runtime regression reproduced the exact error before the fix. All 5,444 main-suite checks, 55 integrated preview checks, and O0/O1 compilation passed after the correction. Regression coverage checks grounded Set/SetBack, nil-air compatibility, airborne glide/no-glide, and native rejection.

A small compatibility patch was applied to the existing live v0.8.153 client without reloading during the match. Afterward two ground Sets were server-confirmed and each was followed by a teammate Spike: one by selected hitter monkaky and the other by ld090812. No new script error was recorded during that observation. This is evidence for the request-path repair, not proof that both deliveries reached the selected hitter or that all ranked receives are reliable.

Other solver misses, rear placement, and hitter-timing limits remain under investigation.

## Download

Rerun the existing loader to obtain the permanent fix. The already patched client can keep running; its version label remains v0.8.153 until reloaded.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

Bundle: `beyond_volleyball_assist.luau` (765,938 bytes).

SHA-256: `77C64AC6C1B5A89B394B63F535580CCF1427D8D086CFEB14F6EE11B737211BA5`.

