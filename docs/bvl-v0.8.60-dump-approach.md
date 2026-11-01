# BVL v0.8.60: validate the dump attack before jumping

Held Dump still prefers a measured native Spike anywhere inside the opponent court, ignoring all player positions. A bad receive or unsuitable jump uses a fast hard Set toward a corner or back line. Releasing Dump restores the selected hitter.

Before committing to a dump jump, the adapter now validates the future measured Spike trajectory and saves its attack heading. If that Spike is unavailable, it tries a reachable grounded intercept with a validated hard Set. It declines an unsupported approach instead of jumping with neither action planned. Final native contact, net/antenna clearance, landing bounds and measured trajectory checks remain. The controller also retains the last ended attempt, including approaches that never request Set or Spike.

Validation: 1,828 main/component assertions and full-bundle Luau compilation at optimization levels 0 and 1 passed. The ranked client verified startup and settings restoration; a read-only receive forecast selected a grounded P13 hard Set instead of an unsupported jump. The user subsequently confirmed that the loaded v0.8.60 build works and requested publication. This confirmation is not a quantified reliability result across all receives or matches.

Bundle: 505,079 bytes. SHA-256: D4CD1530DAF6FE7E9AD1683FB0CEE8723547B2AEB7784CBE35C2E21A5D4E99DD.
