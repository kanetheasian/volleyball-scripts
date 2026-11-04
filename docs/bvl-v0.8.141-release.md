# v0.8.141

Adds **Auto Spike** (disabled by default, mutually exclusive with Auto Set on a single character) along with build-aware contact planning, apex/upper-contact timing, off-net Quick cross catch-up delay, emergency far-corner Set recovery, and optional per-profile window layout persistence.

## Highlights

- **Auto Spike & approach planning**: Acquires a teammate `Set`, `SetBack`, second-touch bump set, or fresh selected-hitter preview from the player's chosen starting position. Evaluates standing jumps and eight-direction native glides using direction-specific native jump power, glide speed, charge travel (including late-charge options), and build/multiplier scope fingerprints. Manual movement retains priority and replans from the new position; completion or cancellation releases movement, aim, and power leases. Held `2` forces immediate Spike eligibility; held `B` prefers modeled block edges.
- **Upper-hitbox & apex contact timing (`quick-catchup-21`)**: Rewards contacts near the upper Spike hitbox band with a 0.45-stud collision reserve, targets just before replicated apex (`PeakWindow`), applies passive same-build jump-height calibration, and delays off-net sharp cross-court `Quick` swings up to 100 ms (`QuickContactDelay`, preserving the final 70 ms of the window) so the ball catches up to the hand instead of clipping the net.
- **Shot planning & block rebound learning**: Commits base yaw immediately before native takeoff lock, freezes armed pitch through contact latency, evaluates oriented `Block` parts with moving-defender velocity and cross-court antenna clearance, and learns per-actor upright block rebounds after two consistent observations.
- **Emergency corner Set fallback**: When an eligible set becomes unreachable for a Spike and `2` is not held, optionally prepares a validated fast far-corner native `Set` (bounded at 2.25 s grounded / 1.6 s airborne with a 5-stud baseline reserve) while retaining a single validated launch window during the 60 ms preparation.
- **Profile window layout**: Saving a named profile stores its current `WindowPosition` metadata outside gameplay `Config` and autosaves subsequent window drags for opted-in profiles without normalizing raw on-disk config values.

## Validation

- 5,242 local assertions and Luau O0/O1 compilation (629,338 / 595,762 bytes) passed.
- Controlled solo private-server batches verified manual-input recovery, 1.15x/1.25x upper-hitbox contacts, front-court/all-play matrices, aimed Auto Set handoffs, and off-net Quick catch-up checks. Multi-account live preview transport and ranked match reliability remain separate.

Bundle: 706,637 bytes.
SHA256: `D10AFA79E3B879A2BCDB147007D786EF4DA112273CCAE48EFEAADF21E0C55ABF`.
