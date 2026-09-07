# /sim-explore PROD — release smoke · 2026-08-21

**GUARDED PROD MODE.** All four gates satisfied before any write:

| Gate | Evidence |
|---|---|
| 1 · Explicit invocation | user ran `/sim-explore prod` |
| 2 · Prod-flavor local build | `flutter run -t lib/main_prod.dart --flavor prod --dart-define-from-file=.env.prod.local`, branch `release/1.24.0` @ `1ff3e659`, bundle `com.milkman.mealvanaendurance`. **Not the TestFlight artifact** — same code, different packaging; the upgrade-from-old-install path (P5) is NOT covered by this session and cannot be, on a simulator. |
| 3 · `is_internal = true` | verified at runtime through the app's own session: uid `f3e1c70e-ba22-454f-bd4a-6a4c0a75c71c`, `xh.analytics@gmail.com`, `is_internal: true` (on the `20260708120000` internal list). Credential supplied by Xuan for this session. First candidate (`avery@test.com`, the only stored credential) does NOT exist on prod — gate would have aborted. |
| 4 · Verified cleanup | see row 10 |

Prod project `wvmvsodrvbkxfydabqed`. Screenshots: session scratchpad `prod/` (00–19).

## Prod state established (read-only probe, before any write)
- **P1 DONE** — `activities.planned_time` / `actual_time` and `plan_recalc_log` all exist (no 42703).
- **P2 DONE** — `calculate-daily-macros-v6` live; frozen `calculate-daily-macros` still parked.
- **P4 DONE** — `release/1.24.0` pushed to origin.
- **P7 NOT DONE** — prod `app_config`: `current = latest = 17`, `min_supported = 11`. This session ran
  in exactly that window (new build, old advertised schema version).
- ⚠ **Stale docs:** app `docs/features/macro_dashboard/README.md` still says *"Nothing prod has been
  touched"* and playbook §0 still lists P1–P7 as remaining. Both are now false in a way that could
  cause a re-run of a deploy. Not corrected by QA mid-release — flagged for Xuan.

## Per-row verdicts

| # | Row | Verdict |
|---|---|---|
| 1 | Sign in | ✅ dashboard reached; **new dashboard renders in prod flavor** (the `MACRO_DASHBOARD_ENABLED` deletion, `adeb1e38`, working) |
| 2 | Version-window: kill + relaunch ×2 | ✅ **no delete-and-resync loop** — 13 activities / 7 targets and identical row identities across both relaunches, with prod still advertising schema 17. ⚠ *But* the app lands on the **onboarding welcome screen** after a cold start, not the dashboard — see Finding 2 (data condition on this account, not a build regression) |
| 3 | Real prod targets render | ✅ v6-shaped: `algorithm_version v6.0.0`, `calculation_input.weight_kg = 47.63`, net −544 kcal |
| 4 | Seed `EXPLORE-run` | ✅ card at its 11:45 slot; **creation flow pops after success** (back → dashboard, no armed form); exactly one row on prod Postgres |
| 5 | Mark done | ✅ **Q-D7 on real prod Postgres**: `planned_time == actual_time == 2026-08-21T11:45:00`, naive-local (no UTC shift — the timestamptz fix holds), `status completed`, `needs_upload` cleared (prod upload drained) |
| 6 | Skip → unskip | ⬜ **NOT COVERED** — deliberately skipped to limit writes on a real account; proven on dev |
| 7 | Targets / calculation_input | ✅ today's row present, v6.0.0, `calculation_input` carries `weight_kg` |
| 8 | Full Breakdown sheet | ✅ 918 / 918 / 918 across card, row and total; **"self-reported" with NO "awaiting sync"** — Q-D4 fix confirmed on prod |
| 9 | Weight change → recompute | ⬜ **NOT COVERED** — deliberately skipped (would mutate the real profile + write real targets); the weight *sensitivity* was proven on dev, and the weight *correctness* is proven here by row 3/4 numbers |
| 10 | Cleanup + verify | ✅ deleted through the app's own path (local `status=deleted`, `needs_upload` cleared), then server-side tombstone + `scheduled_date_time` banished to **2016**; **RE-SELECT: 0 live `EXPLORE-` rows**; account back to its baseline **13** live activities, local and remote agree |

## The release-critical confirmation

This account is **105 lb / 47.63 kg** — the exact profile that reported the 700-kcal bug. On prod:

- create screen **920** · dashboard card **918** · sheet **918** · sheet total **918**
- F4 @ 47.63 kg, 1.8 h, IF 0.74 = **918** ✅
- what the shipped-and-now-fixed 70-kg bug would have shown: **1,349**

**The weight fix is live and correct on production for the athlete who found it.**

## Findings

1. **Minor — engine↔display session-kcal disagree by 8.7%** (display 918 vs engine `session_kcal` 998
   for the same workout; IF source differs across the layer boundary). Display surfaces agree perfectly
   with each other — the 08-20 batch fixed that; this is the remaining cross-layer edge.
   → `ops/data/bug-reports/2026-08-21-engine-vs-display-session-kcal-if-source.md`. Ledger D12.
2. **Not a bug — routing, worth knowing:** cold start lands on the onboarding welcome screen for this
   account because `users.onboarding_completed = false` (verified false both locally and on prod).
   The session persists correctly (valid token in prefs) and the startup gate behaves as written.
   Real athletes have the flag true. The incoherence worth noting: **sign-in routes to the dashboard,
   but a cold start of that same live session routes to onboarding.** Ledger D13, not filed as a bug.
3. **Observation:** create screen 920 vs dashboard 918 — 0.2%, cosmetic (weight-conversion precision).
   Recorded inside finding 1's file, not filed separately.
4. **iOS location prompt** fires on entering Create New Activity Plan (weather). Dismissed
   "Don't Allow" per skill policy; no impact on the flow.

## Verdict

Everything the 2026-08-20 batch fixed is confirmed **live on production**: correct weight pricing,
unified display surfaces, `actual_time = planned_time` written to prod Postgres in naive-local time,
no armed back stack, no "awaiting sync" copy, live plan-detail caption. No release blocker found.
Two charter rows were consciously left uncovered (6, 9) to limit writes on a real account, and P5's
upgrade path remains a human-on-device step this session cannot substitute for.
