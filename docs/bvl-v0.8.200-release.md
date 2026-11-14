# BVL Assist v0.8.200

Landing markers now use twice the live ball radius rather than a fixed 3-stud diameter. The inspected ball radius was 1.099609375, giving a 2.19921875-stud footprint. Native shadows are height dependent; this marker represents the predicted physical ball footprint.

Visual calls use the circle/rectangle overlap geometry found in MatchUtils.isInsideRect, correcting square-expanded corner checks. A stable partial footprint overlap resolves In outside a narrow 0.1-stud tangent band. Recent inward corrections can temporarily expand that band. Pending spin no longer hides current projected footprint calls; later spin can change the prediction. Net contact and missing landing/court data remain Unsure. Defensive decisions are unchanged.

Full regression passed including 87 forecast checks, with quarter-overlap, tangent and corner cases. O0/O1 compilation passed.

Bundle: 900667 bytes. SHA-256: `2a2daf88eff383611579ef05f7818899785e4a78366b7db0723480eb16e141e5`.
