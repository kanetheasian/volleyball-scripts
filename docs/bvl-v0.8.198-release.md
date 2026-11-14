# BVL Assist v0.8.198

Reduce excessive Unsure labels. Visual line calls use the displayed net-aware landing endpoint instead of blanket defensive uncertainty and changing-flight flags. A 0.5-stud minimum boundary margin expands with recent endpoint movement, decaying over 0.12 seconds; a candidate call must persist for 0.06 seconds. Pending spike spin, net contact and missing floor landing remain Unsure. This is a visual confidence heuristic, not a guarantee of server scoring. Defensive out filtering is unchanged.

Full regression passed, including 80 forecast checks (seven new cases), and O0/O1 compilation passed. Live validation and reload could not complete because the Roblox client disconnected. Rerun the loader to update.

Bundle: 899659 bytes. SHA-256: `3869d957f42a86719dc5122a98c2e61b5681008e242dad59acc317ccc8206d9c`.
