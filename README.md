# Volleyball scripts

Run the loader for the script you want. Each loader downloads the current published version.

## Setting (1.9.0)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_set_aim.luau"))()
```

## Friend (1.3.10)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_friend_assist.luau"))()
```

## Spiking (0.2.10)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_spike_assist.luau"))()
```

## Moving spikers and cross plays

Setting now leads a receiver moving sideways along the net, using estimated set travel time at your manually selected power. Spiking includes the same prediction in its setter preview. The target remains 0.2 studs off the net on the setter's side. Rerun both loaders to update.

Prediction is bounded and estimated. It does not retarget an airborne set, and live cross-play accuracy remains unverified.

## Updates

Keep the same loader. Rerun it after a script update to download the published version.
A running script does not automatically update itself.

For maintainers: replace the full script at the same path on the main branch.
Keep the repository name, branch and filenames unchanged to preserve the loader URLs.

These scripts require the same executor capabilities as the standalone files, including game:HttpGet and loadstring. MCP is not required to use the loaders.
