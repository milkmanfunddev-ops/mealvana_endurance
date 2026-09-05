type: ruling-request
bundle: daily-macros-dashboard@v3

## Why this matters
Traced defect (bug-batch item #7, read-only trace 2026-08-20): skipping a workout that RENDERS on
a future day shifts TODAY's burned-so-far by ~25 kcal. Mechanism: the row's `scheduled_date_time`
is today while its `planned_time`/display day is tomorrow — the ENGINE buckets sessions by
`scheduled_date_time` (`daily_macro_service` day queries) while the DASHBOARD buckets by
`actual_time ?? planned_time` (display rule). The skip removes the session from TODAY's engine
bucket, flipping F13's day-modifier DOUBLE(1.15)→TRAINING(1.10), moving NEAT ≈25 kcal — violating
the ratified SKIPPED scope ("zero contribution to THE DAY'S session demand", its OWN day) and
intraday-display §1. The fix is code, but WHICH day-key buckets engine sessions is a contract
choice that touches every session of every day.

## The question
Which timestamp assigns a session to an engine day-bucket: `scheduled_date_time` (status quo),
or the display's own day rule (`actual_time ?? planned_time`), so engine and surface can never
disagree about which day a session belongs to?

## What is already ruled
Two-time model (planned/actual, display = actual ?? planned); SKIPPED zero-contribution scoped to
the session's day; the Garmin completion path deliberately REWRITES `scheduled_date_time` to the
measured start (bug 3a6e3fdb) while `planned_time` keeps the athlete's schedule — so the two keys
genuinely diverge in ratified flows, and nothing names which one buckets the engine.

## Options
1. **Bucket by `actual_time ?? planned_time ?? scheduled_date_time`** (display-aligned; the
   trace's implied fix). Engine day == card day, always. Requires auditing every
   `daily_macro_service` day/context/weekly-hours query.
2. **Bucket by `scheduled_date_time`** (status quo, ratify it) — then the CREATION flow must be
   fixed to write `scheduled_date_time` on the same day as `planned_time`, and the trace's
   repro becomes a data bug, not a bucketing bug.
3. Bucket by `planned_time` only — breaks the Garmin same-day-completion convention.

## Recommendation
(1) — the display rule is the ratified one; a second, unratified key doing the same job is how
this class of bug keeps happening. But (2) is materially cheaper; the trace's repro row should be
pulled first (`SELECT scheduled_date_time, planned_time FROM activities WHERE id=…`) to confirm
how the divergence arose (suspected: creation flow).

## Gates
The #7 fix (deferred from the 2026-08-20 bug batch until this is ruled); the trace record lives
in the batch workflow journal + `ops/docs/dispatches/2026-08-20-macro-dashboard-bug-batch.md` §7.
