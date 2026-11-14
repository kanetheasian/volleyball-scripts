# BVL Assist v0.8.196

Added Visuals > Player specs, enabled by default. Labels beneath other players display their equipped spec and Ready, Active/Jump, or estimated remaining cooldown seconds. Players with no spec have no label. The overlay follows VisualDistance, handles joins, departures and respawns, hides on pause/toggle off, and disconnects on unload.

Replicated Spec and State_SPEC attributes supply the name and readiness. Countdowns begin only on observed transitions into Disabled and use the native phase duration plus action cooldown bonus. A cooldown already running at startup shows Cooldown ?. A zero estimate never claims Ready before replicated Idle.

Full regression passed, including 652 runtime checks; 62 preview-runtime checks and O0/O1 compilation passed. Live verification checked the new toggle and labels. Long-duration unattended behavior and precise countdown accuracy are not established.

Bundle: 898831 bytes. SHA-256: `2e7307007fc5bd97f15281ebbb38a50988c68bd3b80bd0166aabca056a2cedbb`.
