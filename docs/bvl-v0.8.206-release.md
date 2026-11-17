# BVL Assist v0.8.206

Third-touch dumps now require a predicted net crossing between the antennas. A landing inside the opponent court is insufficient when an outside contact travels around an antenna first. Runtime court geometry reads the native per-net antenna offset, rather than assuming the court width matches it. On the inspected ranked center court, that offset was 21.175 studs versus a 21.375-stud court half-width.

The clearance test includes ball radius, net thickness and a 0.25-stud reserve across the crossing interval. Dump Set searches reject illegal routes and consider another baseline depth when the first direction fails antenna clearance. Third-touch Sets recheck from the incoming ball's projected contact and current predicted setting pose before requesting the native action. If no validated crossing remains, they wait for a legal dump. Measured spike-dump forecasts and revalidation apply the same antenna boundary to each segment, including curved flights. Accepted actions retain the existing command lifecycle.

Validation: full regression passed, including 44 dedicated antenna geometry checks, 235 third-touch checks, a corrected outside-receive regression, O0/O1 compilation and 62 preview runtime checks. Coverage includes both sides, rotated courts, resized antenna bounds, ball-edge overlap, rejection of an in-court landing with an illegal crossing, preservation of legal sharp cross-court routes, and the final third-touch request guard. No live ranked behavior is claimed verified; the active ranked client was inspected read-only and was not reloaded during play.

Bundle: 911758 bytes. SHA-256: `70beac72fcddd40f24878937c557072433a7ac706dbb6d038ab4bb2a2f7c0bc7`.
