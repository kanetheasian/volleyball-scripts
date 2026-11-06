# BVL v0.8.144

### Summary
BVL Assist v0.8.144 delivers comprehensive **Blocker Evasion** and **Expanded Court Readability** for Auto Spike. Spikers dynamically evade contesting blockers by routing attacks through open seams, cuts, and angles rather than telegraphing hits or spiking into defenders' hands.

### Key Changes
1. **Blocker Evasion & Seam Aiming**:
   - `planShot` detects all opposing defenders (bots and players) within 8.5 studs of the net with accurate 3D bounding hitboxes.
   - Introduced dynamic evade cut targets: `Block evade seam`, `Block evade deep`, `Block evade sharp`, and `Block seam gap`.
   - Heading lock limit expanded from $0^\circ$ to $52^\circ$ (`math.rad(52)`), allowing spikers to cut shots cleanly around blocker hands while maintaining approach velocity.
2. **Multi-Timing Contact Phases**:
   - Applied defender collision penalties across all timing samples (`Apex`, `Quick`, and `Late`).
   - If a blocker contests apex height, the planner delays the swing to catch the ball on the descent (`Late`) or executes a rapid line drive (`Quick`) into the open gap.
   - Suppressed unrequested tool fallback when `context.preferTool` is false.
3. **Deep Backcourt Range & Run-Up Adjustment**:
   - Spikers starting deep in the backcourt (well behind the 10-foot attack line, $Z \ge 20$) seamlessly initiate sprint run-ups to reach the net takeoff zone without stalling or failing candidate eligibility.
4. **Cache & Stability**:
   - Calibrated character models and hitter reach samples remain active across extended match sessions without 600-second expiration drops.

### Validation
- **Unit Tests**: All 320 AutoSpike tests, 144 spike tests, 399 runtime tests, 394 assist tests, 454 auto-set tests, and 2,094 scenario tests passed (100%).
- **Bytecode Compilation**: Passed Luau bytecode compiler at both `-O0` (647,848 bytes) and `-O1` (607,161 bytes).
- **Live Match Verification**: Tested live in-game with teammate setter `ld090812` and dynamic blocker bots:
  - *Contested Outside Wing ($X = -14$)*: Selected `Block evade seam` to $X = -17.38$, clearing the blocker by 3.38 studs.
  - *Deep Court Run-Up ($Z = 20$)*: Sprint run-up covered 16.5 studs to takeoff at $Z = 3.42$ and cut cross-court to $X = -8.99$, clearing the mid-cut blocker by 4.99 studs.
  - *Dynamic Sweeping Blocker ($X \in [-14, -2]$)*: Punched a reactive line kill into the open middle ($X = -0.42$) with 7.58 studs clearance.
  - *Elevated Apex Contest ($Y = 18$)*: Collision avoidance held the swing until an open trajectory emerged rather than hitting into the block.

### Bundle Details
- File: `beyond_volleyball_assist.luau`
- Size: 730,839 bytes
- SHA256: `C2F3BC591D08E39C1EADADB96ADE2EAADAF5BE0DFCA7EE115D92BD138229ED9A`
