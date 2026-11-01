# BVL v0.8.59: held Spike dump and hard Set recovery

Holding B or the Dump button overrides the selected hitter. The preferred action is a measured native Spike landing anywhere inside the opponent court. Held-dump selection and final validation ignore all player positions, including receivers and blockers. Net, antenna, court bounds, contact matching and native reach/turn limits remain. General manual Spike aiming retains its existing behavior.

When the receive or jump cannot support a Spike, held recovery searches both corners and the back line for a fast, deep native Set. It excludes the old weak midcourt best-effort recovery. A physically impossible trajectory may produce no shot rather than a known weak or out-of-bounds dump. Releasing Dump restores the selected hitter; missing hitters and failed ordinary trajectory searches no longer silently select an opponent-court dump.

The approach considers compatible measured jump phases and retries early unmatched Spike contacts until a bounded recovery deadline. A preparation-only aiming plan may support the jump when no hard Set exists, but cannot dispatch a Set.

Validation: 1,823 main/component assertions and full-bundle Luau compilation at optimization levels 0 and 1 passed. A ranked client verified startup, settings restoration and a read-only hard-recovery forecast. Successful real-match Spike and fallback outcomes for this release remain unverified; these local checks are not a gameplay reliability guarantee.

Bundle: 502,085 bytes. SHA-256: FC5748CB536A0C58C33D879887207139616600BC5B2112679D43FAAEE5EB84A6.
