type: ruling-request
bundle: (next data-integrations bundle — deliberately NOT in the corpus bundle; needs its own vectors)

## Why this matters
Basic-tier TP athletes with unnamed workouts fall to the §7.1 default (`moderate`) — an easy
6-miler and a speed-work 6-miler price identically. One unused signal exists for everyone.

## The question
Add a fifth rung to the ratified §7.1 intensity ladder: for STEADY efforts, classify by
**planned pace vs the athlete's own threshold pace** (from `/v1/athlete/profile/zones`,
reachable under the current grant for every tier — shape captured 2026-09-18)?

## Context (what is already true)
- §7.1 ladder as ratified: planned IF → TSS/hr → title keywords → default. Rungs 1–2 fire
  for premium/coached athletes once the casing fix ships (ops Critical); rung 3 carries
  basic athletes with descriptive titles; this request covers only the remainder.
- Filed at Xuan's instruction during the 2026-09-20 corpus interview ("file it as the next
  intake") after confirming the revived §7.1 ladder as the mechanism, unchanged.

## The honest limitation (must be in any ruling)
Planned pace = DistancePlanned ÷ TotalTimePlanned is an AVERAGE. Interval sessions include
recoveries, so a hard session can average "easy" — the rung is honest for steady efforts
and BLIND to intervals. Any ruling needs: (a) a steadiness precondition or an explicit
"average-pace heuristic" label, (b) provenance — a classification from this rung must be
distinguishable from a measured one (drawer honesty), (c) spec-derived vectors incl. the
interval false-negative case as a documented non-goal.

## Options (sketch — to be re-briefed when the bundle opens)
- A: add the rung, gated to workouts with no structure/IF/TSS/title signal, labeled derived.
- B: don't add; basic unnamed workouts stay `moderate` by default.
- C: post-hoc only — classify from ACTUALS after completion (HR avg vs the athlete's zones),
  never from planned pace.

## Gates
- [ ] Ruling + spec fold into payload-usage-map §7.1 (new rung text)
- [ ] Spec-derived vectors (steady, interval false-negative, missing-zones fallback)
- [ ] Drawer provenance treatment for derived intensity
