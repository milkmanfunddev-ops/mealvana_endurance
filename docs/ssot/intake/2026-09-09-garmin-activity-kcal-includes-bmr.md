> **RESOLVED 2026-09-10 → option 1 (ruling desk 2026-09-10): raw stored verbatim; F22 resolves session kcal = calories_burned − RMR/24 × duration_hr, floor 0. CONTRACT CHANGE (class c) — staged for ship-bundle daily-macros-dashboard@v4; no fold into the current platform-resolution.md**
type: ruling-request
bundle: daily-macros-dashboard (platform-resolution F22) + data-integrations@v1

## Why this matters
Xuan's suspicion (2026-09-09), now confirmed against Garmin's spec: the Activity API's
`activeKilocalories` — the value we store as `activities.calories_burned` and use as the
measured session kcal (F22's top rung; `dashboard_assembler._sessionKcal`) — "**Includes
activity + BMR calories**" (`docs/integration/api-exploration/garmin/activity-data.md:23`,
`field-reference.md:30`). The Health API daily field of the same name **excludes** BMR
(`health-data.md:44`). Because the engine separately accounts the athlete's full-day RMR,
every Garmin-verified session double-counts its duration's BMR share — roughly
RMR/24 × duration_hr ≈ 65–75 kcal per exercise hour for a typical athlete. The dashboard
and fuel math run hot by that amount on exactly the athletes whose numbers we call
"verified."

## Empirical proof (Xuan's own run, 2026-09-10)
Garmin Connect displayed the split for the run: **Active 393 · Resting 42 · Total 435**.
The raw API payload we received (prod `garmin_health_data` activity_raw, 12:41 UTC,
RUNNING, 2655 s) carried exactly ONE calorie field: `activeKilocalories: 435` — the
TOTAL, despite the name; the 393 active figure is never sent, and no resting/total split
exists anywhere in the payload (full key audit via `query-ledger.sh garmin-kcal`).
Cross-check of the proposed fix: 42 resting kcal over 44:15 ≈ 57 kcal/h ≈ RMR/24 — so
option 1's subtraction recovers ≈393 from the 435 we receive, reproducing Garmin's own
Active number from data we already have.

## The question
How does the measured-kcal rung correct for the embedded BMR — and at which layer?

## What is already ruled
`spec/daily-macros/platform-resolution.md` (RATIFIED v2): Garmin `ActiveKilocalories`
replaces `sessionCost()` — the ladder text does not name the BMR embedding. The F4
formula it replaces prices *activity* work; the two are therefore not like-for-like.

## Options
1. **Correct at the resolution rung (recommended):** store the raw value verbatim
   (lose-nothing policy, Xuan 2026-09-09), and at F22 resolution compute
   `session_kcal = calories_burned − resolved_RMR/24 × duration_hr` (floor 0). Raw data
   intact; one ruled formula; both engine and display inherit it.
2. **Correct at ingest:** subtract before writing `calories_burned`. Simpler consumers,
   but the stored value no longer matches Garmin's payload (violates lose-nothing) and
   the correction silently depends on the RMR known at sync time.
3. **Ratify as-is:** accept the double count as measurement noise. Zero work; the
   "verified" number stays systematically high, worst for long sessions.

## Gates
- If ruled 1/2: platform-resolution F22 erratum + regenerated vectors for the measured
  rung; app change in `_sessionKcal` and `calculate-daily-macros*` session resolution;
  smoke re-check of a Garmin-verified day.
- Cross-ref: `spec/integrations/payload-usage-map.md` §3.1 (mapping accuracy is goal 1 of
  the 2026-09-09 direction), Q-INT26 capture contract.
