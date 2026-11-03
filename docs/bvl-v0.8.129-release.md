# BVL Assist v0.8.129

Spiker aim now uses a long, opaque, outlined line that respects court occlusion. Yellow indicates an estimated floor landing from matching measured shot data; after a Spike it uses the ball's replicated flight. Gray indicates body aim when matching shot data or recent player power is unavailable. The guide follows a nearby ball's height and clears confirmed-flight tracking at the next touch, landing or expiration.

This release changes visuals only relative to v0.8.124. Opponent power before contact remains an estimate from recent replicated hits. Net touches and blocks can change the landing. Fresh live landing accuracy remains unverified: the passive live read observed fallback guides, without a matching forecast event.

Published exact 600667-byte tested bundle. SHA256: A48E127AD982C7AD2DEAC254984DCA9039C2EAEEE321139F4A432C134E1C285C. Validation: 4400 local assertions, 52 preview-runtime checks, and O0/O1 Luau compilation. Live load confirmed v0.8.129, Alive=true, Errors={}.

The v0.8.124 dump limitations remain, including intermittent empty jumps and back-row Set fallbacks. Rerun the existing loader to update an older running copy.
