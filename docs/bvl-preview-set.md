# Preview Set

BVL Assist v0.8.49 includes **Visuals → Preview Set**, enabled by default. The regular loader includes the full preview; no separate Roblox companion script is needed. Turning the toggle off hides the preview and stops publishing planned sets. The preference follows profiles, reloads, Pause All and script cleanup.

When Auto Set is active, the setter can see the planned trajectory locally. The first feasible attack marker stays anchored while the hitter moves and jumps. Small curve corrections retain the target. A material flight change can replace the target, and an unreachable replacement clears it. Amber denotes a provisional or revising plan. Native contact switches to the confirmed launch trajectory. Power, native contact position and later actions can still differ from the earlier prediction.

## Sharing the preview with the spiker

The tested sharing transport is a local data link. Both Roblox accounts must run on the computer running the helper. It does not connect players on separate computers, and the main script does not provide an externally hosted relay. The local setter preview works without a link.

With Node.js installed, download `bvl-preview-local-link.mjs` from this repository and run it with the current Roblox JobId and setter's numeric UserId:

```powershell
node bvl-preview-local-link.mjs --job "<Roblox JobId>" --setter <setterUserId> --seconds 21600
```

The helper binds only to `127.0.0.1:16385` and generates `artifacts/bvl-preview-local-link-config.json`. That local file contains the URL, setter ID and separate generated write/read tokens for this running link. No chat messages or game actions are sent by the link.

Before running the regular loader on the setter, configure its role and the generated **writeToken**:

```lua
getgenv().BVLSetPreviewRole = "setter"
getgenv().BVLPreviewTransport = {
    url = "http://127.0.0.1:16385/snapshot",
    token = "<writeToken from your local config>",
    setterUserId = <setterUserId>,
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

On the spiker, use role **spiker** and the generated **readToken**, with the same setter UserId and URL. Select that spiker in the setter's Auto Set controls. Each player controls their own Preview Set toggle under Visuals.

The helper stops after six hours with the command above. Stopping it expires shared planned visuals. Restarting it generates new tokens, which must be applied to both configurations. No generated token is part of the published Roblox script. To stop the helper early, press Ctrl+C in its terminal.

## Verification boundary

The earlier two-player trial confirmed successful native spike contacts and useful lead time. It also showed marker error, missed markers and occasional late power/direction changes. The preview is a provisional guide, not a guarantee of an exact future contact point.

This release adds the default-on Visuals control, integrated startup/cleanup, automatic local role selection and removal of the trial's fixed setter-account requirement. Offline runtime fixtures verify those integration paths. No Roblox clients were connected for a live test of the new menu integration at publication time. Set and dump tuning were not changed for this release.
