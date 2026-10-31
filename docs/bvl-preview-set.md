# Preview Set

BVL Assist v0.8.53 shares planned Auto Sets between script users on different computers through a hosted HTTPS relay. Every player uses the regular loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kanetheasian/volleyball-scripts/main/beyond_volleyball_assist.luau"))()
```

Both the setter and viewers must reload version 0.8.53 or newer, join the same Roblox server, and enable **Visuals → Preview Set**. The toggle is on by default; a previously saved off preference remains off. The setter runs Auto Set normally. Nearby script users can see the planned trajectory and reachable attack marker, including when the set targets another teammate. A viewer's own active Auto Set plan takes priority.

No Node helper, MCP connection, manual token, setter ID, or separate companion script is needed. The main script ignores the older local-link role and transport settings. The old localhost helper is retained only for the standalone prototype and is unnecessary for the current main script. Players without the script cannot see these client visuals.

The relay is https://bvl-shared-preview-relay.ornatehutch.chatgpt.site/api/preview. Sessions and frames are scoped to the Roblox server JobId. A client receives a short-lived capability automatically and reconnects after expiry. Frames expire after 850 ms, so interrupted sharing does not leave an old planned arc active indefinitely. Disabling the toggle hides the preview, cancels an active publication, and stops polling. Script cleanup stops the owned transport and visuals.

The relay carries JSON preview data only: server and player identifiers, set parameters, trajectory samples, and confirmation metadata. It does not send chat or issue game actions. Enrollment uses client-declared Roblox identifiers; the relay does not authenticate Roblox account identity. The viewer also checks that the named sender and target exist in its current game server.

The marker is a provisional timing guide. Small corrections retain the attack target; a material flight change can replace it. Amber indicates a provisional or revising plan. Native contact switches to the confirmed trajectory, which can differ from the prediction. The Internet relay adds latency, so early visibility depends on the available planning lead time and each player's connection.

Validation for this release: 1,769 main/component assertions, 43 preview-runtime assertions, 11 Rayfield compatibility checks, and main/companion Luau compilation passed. The backend passed 23 SQLite checks and 14 public HTTPS integration checks, including independent-session delivery, server isolation, ownership restrictions, ordering, cancellation, and expiry. A connected Roblox executor received HTTP 200 from the public relay health endpoint. A two-computer native gameplay test has not yet been completed for this release. Version 0.8.53 updates dump fallback and Spike landing safety; see bvl-v0.8.53-dumps.md.

## Executors with limited controller access

Version 0.8.52 automatically starts a preview-only viewer when GC enumeration exposes no Lua tables. This matches the reported Xeno capability check. The viewer uses the native module loader when available and receives the same shared trajectories and native contact updates. It does not attempt to locate or automate a player controller. Its small Overview and Visuals menu includes Preview Set, enabled by default, and Unload. Automatic setting, aiming and movement are unavailable in this mode.

A saved off preference is preserved across viewer reloads. Turning the toggle off hides the preview and stops polling. Unloading or replacing the viewer releases its visuals, native event listeners, relay loops and menu. A failed startup also cleans up the receiver. Executors exposing Lua tables retain the existing full-assist startup path.

The viewer path passed a fixture reproducing the capability report: getgc exposes no Lua tables, the executor require errors, and the distinct native require returns BallUtils and BallPackets. The friend confirmed that the preview-only menu opens in Xeno. Shared network visibility and gameplay on that executor still require live verification. The bundle also compiles at both optimization levels 0 and 1.