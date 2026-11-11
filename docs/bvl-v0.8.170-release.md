# BVL Assist v0.8.170

Movement adds a Diagonal tilt toggle for normal jumps. Press W+A, W+D, S+A, or S+D during a jump. With the default angles, the diagonal has the same overall lean as a cardinal tilt. The toggle is enabled by default and the existing tilt multiplier applies when enabled.

BVL still handles native trait combinations and jump blocks. An active Auto Set retains control of its tilt.

All four chords passed local tests in both key orders. The main suite passed 5,660 checks, the preview runtime suite passed 62 checks, and the bundle compiled at O0 and O1. In-game diagonal tilt validation is pending.

The previous release documents the Auto Set changes and private-lobby drill. [v0.8.169 release notes](bvl-v0.8.169-release.md)

Rerun the existing loader to update.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

Bundle size is 832,238 bytes. SHA-256 is `09E6153462D74DFF573EEB50F67AAF81178D9D26B368331B929440672122BDB6`.
