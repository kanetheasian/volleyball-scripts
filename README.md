# Volleyball scripts

Run the loader for the script you want. Each loader downloads the current published version.

## Setting (1.9.2)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_set_aim.luau"))()
```

## Friend (1.3.10)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_friend_assist.luau"))()
```

## Spiking (0.2.11)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_spike_assist.luau"))()
```

## Moving spikers and cross plays

F targets KEDO_EV (58427452) when a friend runs the setting script. On KEDO_EV's account, F still targets sippywippy. The same-court nl223602 fallback and R target remain available.

Setting now leads a receiver moving sideways along the net, using estimated set travel time at your manually selected power. Spiking includes the same prediction in its setter preview. The target remains 0.2 studs off the net on the setter's side. Rerun both loaders to update.

F/R now chooses one meeting point per press, with small, bounded corrections instead of continually chasing the runner. Press F/R again after a large route change or power change. Replicated movement is filtered to reduce packet jitter.

Prediction is bounded and estimated. It does not retarget an airborne set. A remote spiker's preview estimates the target; it cannot read the setter's private committed plan. This stability revision passed offline checks; live cross-play accuracy remains unverified.

## Updates

Keep the same loader. Rerun it after a script update to download the published version.
A running script does not automatically update itself.

For maintainers: replace the full script at the same path on the main branch.
Keep the repository name, branch and filenames unchanged to preserve the loader URLs.

These scripts require the same executor capabilities as the standalone files, including game:HttpGet and loadstring. MCP is not required to use the loaders.
