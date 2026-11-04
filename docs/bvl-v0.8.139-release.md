# v0.8.139

Moving Auto Set now reapplies a committed glide direction immediately before native takeoff samples movement input. This prevents an intervening input reset from turning that planned glide into a vertical jump. The correction is limited to the current character's accepted, unexpired glide charge and yields to manual movement, focus loss, typing/menus, disabled native inputs, serving, blocking and movement locks. Native jump/glide physics remain unchanged.

Takeoff diagnostics now record the applied direction and observed native glide speed. Existing profiles and selected hitter/play settings are preserved. All v0.8.138 changes remain included.

Validation: 4,908 local assertions and O0/O1 compilation passed. Five planned glides in live bot-court simulations produced native glide, confirmed Set contact and simulated-hitter contact. Four succeeded after movement input was deliberately cleared immediately before takeoff. Natural ranked play also confirmed selected-hitter Sets, including two followed by net-clearing spikes. Ranked automatic glide-Set success was not independently confirmed before MCP disconnected; no universal reliability claim is made.

Bundle: 635,366 bytes.
SHA256: 5022944B1DE82F4D865649BFDD2BDF807DB08788D78F844EF3BF655D05B08A26.
