# Round pilot — 2026-09-26 — FAIL

Average Mark 71.25. Pass needs average >= 90 and no Run below 80.

| Scenario | Account | Mark | Cap | Improvements |
|---|---|---|---|---|
| s07-veg-dinners-after-long-runs | judging-1 | 71.25 | — | IMP-001, IMP-002, IMP-003, IMP-004 |

## s07-veg-dinners-after-long-runs (judging-1)

| Dimension | Mark | Weight |
|---|---|---|
| dietitian-judgment | 50 | 20 |
| task-success | 75 | 15 |
| concision-restraint | 100 | 10 |
| interactivity | 50 | 10 |
| tool-use-data-ops | 75 | 10 |
| memory-personalization | 50 | 10 |
| reliability | 100 | 10 |
| opener | 50 | 5 |
| instruction-following | 100 | 5 |
| recovery-boundaries | 100 | 5 |

Mark 71.25.

Task achieved: three vegetarian, protein-forward, peanut-free dinner ideas framed for long-run recovery; a pick emerged; the tofu bowl was logged for dinner with correct macros (verified in meal_logs) and the tree-nut correction was saved as a memory (rememberFact verified). Top defects: (1) IMP-001 — the allergy field was read but only peanut applied; walnuts (tree nuts, same list) were suggested, including as the athlete's own saved meal; (2) IMP-004 — the opener read as a dashboard briefing, not one thing this athlete told her; (3) IMP-002 — the correction was remembered silently, never acknowledged; (4) IMP-003 — no tappable parts anywhere in the Run: pick and log happened in prose. Anchor questions for calibration: interactivity had nothing to press (marked 50 for the design gap, not a failure — anchors do not cover "no parts offered"); the opener sits between the 50 and 25 anchors (specific but a data read-out). Robotic cap not applied: replies built on the athlete's own words (saved meal, carb overage, the correction).

Improvements: IMP-001, IMP-002, IMP-003, IMP-004
