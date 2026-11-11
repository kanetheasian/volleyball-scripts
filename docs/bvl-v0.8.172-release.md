# BVL Assist v0.8.172

Diagonal tilt now follows held WASD keys during normal jumps and jump serves. Holding S tilts back, adding A tilts back-left, and releasing S while continuing to hold A changes to left tilt. Releasing all tilt keys returns upright. The existing Diagonal tilt toggle controls this behavior.

Serving adds Auto Power, enabled by default. The script waits until the native V-toss ball appears, then selects P12 for Float or P15 for either topspin preset, bounded by the player's maximum power. The first contact on that ball, removal, cancellation, or timeout resets power to P3.

Topspin Left and Topspin Right use the exact upper spin-meter corners by default. Existing profiles with the former default offsets upgrade to the corners. Custom offset pairs are preserved.

Validation passed 5,694 main checks, 62 preview runtime checks, and compilation at O0 and O1. Private-client recordings observed S to S+A to A transitions, combined tilt on a jump serve, and native P12 Float and P15 topspin hits followed by the return to P3. Full-match reliability and other builds remain unverified.

Rerun the existing loader to update.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

Bundle size is 837,596 bytes. SHA-256 is `E38E957E2E3380A179179F64385DDFB0CC369DA67829BCB471C45402AB56026F`.
