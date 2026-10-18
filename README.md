# Volleyball scripts

Run the loader for the script you want. Each loader downloads the current published version.

## Setting (1.10.0)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_set_aim.luau"))()
```

## Friend (1.3.10)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_friend_assist.luau"))()
```

## Spiking (0.3.0)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_spike_assist.luau"))()
```

## Control center

Setting and spiking now have a dark tabbed GUI: Overview, Defense, Visuals, Keybinds and Profiles. Both include Auto Receive and Auto Dive, OFF on fresh settings. Right Shift hides/shows the menu while enabled assists and overlays keep running. Default shortcuts: 7 receive, 4 dive, 5 aim, Insert paths, and 6 spiking full assistance. Rebind them in Keybinds.

Profiles save toggles, sliders and keybinds separately per account and script. Settings restore on reload. With file access, named profiles persist on this device; otherwise they last for the client session. Enabled assists resume when a saved configuration loads. Full-assistance calibration remains separate.

If both scripts are loaded, the SETTER/SPIKER button selects which menu is visible. They share one receive/dive controller. The standalone friend edition keeps its existing menu. Compilation, mocked startup/input tests and layout previews are local validation; live match and device testing remain pending.

## Moving spikers and cross plays

On ld090812's account (415710999), F targets sippywippy and R targets KEDO_EV (58427452). On KEDO_EV's account, F targets sippywippy and R targets ld090812. Other accounts retain F for KEDO_EV and R for ld090812. F retains the same-court nl223602 fallback; R has no fallback.

The panel title shows the version and its footer reflects the account's actual F target. When F is unavailable, the status names the primary target's rejection reason. This diagnostic update does not establish that the reported live court rejection is fixed.

Setting now leads a receiver moving sideways along the net, using estimated set travel time at your manually selected power. Spiking includes the same prediction in its setter preview. The target remains 0.2 studs off the net on the setter's side. Rerun both loaders to update.

F/R now chooses one meeting point per press, with small, bounded corrections instead of continually chasing the runner. Press F/R again after a large route change or power change. Replicated movement is filtered to reduce packet jitter.

Prediction is bounded and estimated. It does not retarget an airborne set. A remote spiker's preview estimates the target; it cannot read the setter's private committed plan. This stability revision passed offline checks; live cross-play accuracy remains unverified.

## Updates

Keep the same loader. Rerun it after a script update to download the published version.
A running script does not automatically update itself.

For maintainers: replace the full script at the same path on the main branch.
Keep the repository name, branch and filenames unchanged to preserve the loader URLs.

These scripts require the same executor capabilities as the standalone files, including game:HttpGet and loadstring. MCP is not required to use the loaders.
