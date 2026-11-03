# v0.8.136

Held-B Spike dumps now separate early takeoff from the swing, with the final swing timing trimmed about forty milliseconds later after manual-reference feedback. Native swing requests are no longer vetoed by predicted net clearance, landing, opponents, or missing launch calibration.

The approach planner compares eight aim-relative glide directions, including diagonals, and favors the shortest ground approach with a small attack-alignment preference. Comparable high contacts retain priority. It uses native glide-speed prediction, reserves vertical reach, limits contact-point overshoot, and can learn a lower measured jump. Normal selected-hitter Auto Set and held-2 forced Set behavior remain separate.

Fixed a follow-through cleanup gap that could retain assisted facing after a confirmed contact had released its job. Landing or dump release now clears the remaining owned facing state.

Validation: 4,851 local assertions and O0/O1 Luau compilation passed. The final solo native-bot batch produced eight confirmed P15 Spikes from eight feeds across behind, diagonal-left, diagonal-right, and wide opposite-side receives; all eight landed in the opponent court. Diagonal glides were observed. Tests used 1.15x jump and ordinary S tilt. This is solo bot-court evidence, not ranked or every-position reliability proof. Earlier revisions still missed some contacts, and a faster P6 feed from a distant starting position remains unresolved and was not included in the final eight-feed batch.

The tested bundle is published unchanged. Test controls and user settings were restored, feeds stopped.

Bundle SHA256: 560298826E1022A0E8A75B064E73107651B8D56E748B15E39700EFD5B37E2F07 (624,720 bytes).
