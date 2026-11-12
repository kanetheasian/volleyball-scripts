# BVL Assist v0.8.183

Close Normal sets now prefer at least power 3 when the hitter is within 16 studs and that power has a legal delivery in the same arc-quality tier. This addresses a close setup that was selecting power 2 and contacting the back of the hitter volume. The solver retains a legal lower-power set when stronger options are unavailable, respects the player's power maximum, and keeps the existing selection outside the close range. This preference applies to Normal; Quick and other plays retain their existing power rules.

Two isolated balls in the current close practice-bot setup selected power 3, produced confirmed Sets and target Spikes clearing the net, and reached hitter contact at world Y 18.62 and 18.51. Native flight times were approximately 1.37 and 1.30 seconds, versus roughly 1.52–1.58 seconds on the preceding power-2 examples. These are small sequential practice results, not a general reliability guarantee.

This cumulative release also includes diagonal blocking tilt: W+A, W+D, S+A and S+D combine pitch and roll during blocks. Native lateral block arm callbacks, key-release behavior, the existing Diagonal tilt toggle and optional multiplier are preserved. Live observation confirmed W+A/W+D block poses; all four combinations and both key orders are covered offline. Blocking effectiveness against incoming attacks remains unverified.

Normal contact planning includes rising contact windows, native command settling, corrected incoming/hand timing, aim corrections through accepted glide Sets and a practice-bot contact-volume estimate derived from replicated contacts. Isolated bot checks validated upper hitter contacts; moving real hitters and ranked reliability remain unverified. High can still use a quicker legal recovery when its requested slow-lob profile cannot be solved.

Validation: full regression suite passed, including 10 new close-power checks for both court sides, legal lower-power fallback, range limits and player power limits. Runtime checks: 496. Preview runtime: 62. Generated bundle compiles at O0 and O1.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

Rerun the loader to update an existing session. The menu version should show 0.8.183. GitHub's raw main URL may briefly serve a cached earlier version after publication; the publication record includes a commit-pinned download for exact bytes.
