# BVL Assist v0.8.173 — Quick power update

Release v0.8.173. No client mutations or match actions were performed for this change. Live validation of the Quick changes remains pending.

## Behavior

- Quick searches available powers from P15 downward (or the player's lower maximum), checking each power's legal tilts before lowering power.
- Native Quick launch calculations use Quick placement, including the led hitter point, instead of defaulting to Normal placement.
- Initial Quick interception supplies the predicted native setting center and may examine up to nine reachable contact times within the existing planning budget before retaining a slow fallback.
- Airborne execution updates the predicted native setting pose and uses native aim compensation. Quick preview uses the same commanded point.
- Quick recovery retries a fast Quick before Normal recovery. A genuinely unavailable Quick retains the existing selected-hitter Normal save.
- Normal arc selection remains independent of a successful Quick. Practice-bot Quick trajectories also obey the 1.15-second flight limit.

## Validation

- Full scripts/test-bvl-assist.mjs passed, including 62 new Quick assertions.
- scripts/test-bvl-preview-runtime.mjs: 62 checks passed.
- Generated bundle compiled at O0 and O1.
- beyond_volleyball_assist.luau: 839247 bytes at build.
- Fixtures exercise both court sides, lower max power, P15 cap, competing lower-power neutral solutions, native aim and pose propagation, led points, later interception, and explicit Normal fallback.
- Synthetic/local results do not establish actual live ball arrival accuracy. Multiplayer/private-lobby live validation remains outstanding.
