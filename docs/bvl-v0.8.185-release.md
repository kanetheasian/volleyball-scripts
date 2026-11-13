# BVL Assist v0.8.185

With Auto Set enabled, a teammate's second observed team contact now routes the setter's next contact to the existing opponent-court dump planner. This replaces the four-touch-court exception that could select another teammate set on touch three. A normal first receive still gets a second-touch hitter set. The third-touch policy also works without an available selected hitter and can reacquire a revised ball while the setter is already airborne.

The dump uses the existing validated Spike/Set recovery choices and the current Auto Set jump and Spike-dump settings. It does not simulate held B or invoke the unconditional manual swing. Opponent balls, own previous contacts, spent/dead/rolling revisions, receiver coverage, disabled automation and manual-input locks remain excluded. Touch counts of three or more do not authorize an automatic fourth contact. Courts explicitly limiting the team to two contacts are excluded.

Routing is local to one ball revision. A confirmed contact cannot be repeated, and an accepted dump keeps its route while its revision is marked used and awaiting the native Hit packet. Another practice ball cannot retarget an accepted action. A pending, unaccepted job can yield to a different two-touch ball without dumping the old first-touch ball.

Validation: full regression suite passed, including 231 third-touch eligibility, ground/air, both-side, revision handoff, request-lifecycle and multiple-ball checks. The same 231 checks passed in the connected Roblox client with real client types/native physics and isolated request stubs; this did not fire game remotes or spawn balls. Preview runtime: 62 checks. Generated bundle compiled at O0 and O1. v0.8.185 was loaded with Auto Set enabled, manual Dump released and no reported runtime errors. No actual third-touch rally has yet been observed on this build.

Bundle: 870,132 bytes. SHA-256: `0ae40f0e12697a1145790e3a49c3f685cb2e68d73af4aaf2221eb061ff075fbf`.

Rerun the existing loader to update. The menu version should show 0.8.185.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

