# Volleyball scripts

Run the loader for the script you want. Each loader downloads the current published version.

## Beyond Volleyball League (0.8.29)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

Court-mode Spike Aim now compares tight crosses, deep corners, lines and seams using an incoming-ball contact estimate, native power, contact height, the authored net, active block hitboxes and moving receivers. It applies native forward/back tilt as well as heading, refreshes while airborne, updates immediately before a requested swing, and locks after that request. Clear routes take priority; measured-model block-edge contacts are labeled tool attempts, whose rebound outcome is uncertain.

Confirmed own spike launches build bounded models for matching power, contact height and tilt, including measured spin and bearing. Before matching samples exist, the planner explicitly uses an uncalibrated flight estimate; it does not have the private server shot calculation. Native tilt is limited to 20 degrees. Shot accuracy and block tools are not guaranteed. If no in-bounds, net-clearing flight is found, the planner releases its aim instead of retaining a stale attack.

The existing background Auto Move, manual movement override, receive-power restoration and Auto Set behavior remain covered by the regression suite. Profiles and toggles retain their saved values.

Validation: 1,158 local checks passed, including 21 shot-planner checks and runtime regressions for physical tilt, pre-swing refresh/locking, cleanup and later manual ownership. Published script bytes were verified. Version 0.8.29 started in the connected client with no startup errors. Complete live spike, receiver-avoidance and block-tool match testing remains pending.

## Setting (1.11.2)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_set_aim.luau"))()
```

## Friend (1.4.0)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_friend_assist.luau"))()
```

## Spiking (0.4.0)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/volleyball_spike_assist.luau"))()
```

## Jump height multiplier

All three scripts share a single jump controller. When enabled in Overview, an input box allows configuring the height multiplier:
- **Default:** `1` (normal height)
- **Boosted:** e.g. `1.2` for 20% extra height (~1.3 extra studs rise)
- **Range:** `0.1` to `2.0` (invalid inputs safely retain the previous value)
- **Safety:** The boost adjusts `JumpPower` only during takeoff using square-root scaling, and restores native values immediately during ascent or when unloaded. Calibration resets automatically if Full Assist is active.

## Tilt multiplier

All three scripts share an opt-in tilt multiplier. In Overview, enable **Tilt multiplier**, then enter **Tilt amount**.

Default is OFF at 1x. Range: 0.1-3. A value of 2 doubles native forward/back and sideways lean. Each target axis is limited to 80 degrees. The controller restores native targets on disable, landing, death, or final unload, and multiple scripts share one controller. Changing the factor invalidates full-assist calibration.

This changes the native airborne body-tilt target. The game's shot calculation has a separate input clamp; extra shot power/range and server acceptance have not been established by offline checks.

## Control center

All three scripts use Rayfield with Overview, Defense, Visuals, Keybinds and Profiles tabs. Each includes Auto Receive and Auto Dive, OFF on fresh settings. Right Shift hides/shows the menu at its last dragged position while enabled assists and overlays keep running. Nested value bars and labels fade together with the window. Default shortcuts: 7 receive, 4 dive, 5 setting/spiking aim, Insert setting/spiking paths, and 6 spiking full assistance. Rebind them in Keybinds. If Rayfield cannot load, the bundled menu remains available as a fallback.

Profiles save toggles, sliders and keybinds separately per account and script. Settings restore on reload. With file access, named profiles persist on this device; otherwise they last for the client session. Enabled assists resume when a saved configuration loads. Full-assistance calibration remains separate.

The scripts retain their shared jump, tilt, stamina and defense ownership. The setting Rayfield window and its position/fade behavior have been verified in a connected client. Compilation and mocked runtime checks also passed; complete match and device testing remains pending.

Setting v1.11.1 fixes a jumpset cleanup bug that could restore the game's temporary airborne rotation lock after landing. The assist releases only rotation control that it acquired itself. The regression is covered by lifecycle tests; actual jumpset playtesting remains pending.

## Moving spikers and cross plays

On ld090812's account (415710999), F targets sippywippy and R targets KEDO_EV (58427452). On KEDO_EV's account, F targets sippywippy and R targets ld090812. Other accounts retain F for KEDO_EV and R for ld090812. F retains the same-court nl223602 fallback. Setting v1.11.2 adds fartfart3734 (5562270760) as the secondary R target when the primary R target is unavailable or on another court/side; the primary R binding is unchanged.

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
