# SSOT — Daily Targets (consumption contract)

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** the daily-macros SSOT, `docs/ssot/spec/daily-macros/` (Engine B), is authority for the numbers
themselves; this file says only how Vana *reads* and *back-fills* those rows. It defines no formula.
**Code:** `ensureWeekTargets` — prototype `server/vana/macros.ts`, edge `_shared/vana/macros.ts`.
**Scope:** the consumption contract — never recompute, back-fill on gaps, fail open, minimums framing, and the
two derived quantities (`planningKcal`, `lunchDinnerKcal`) Vana adds on top of Engine B's rows.

## The rule

- **T-1 · Never recompute.** Vana reads `daily_macro_targets(user_id, target_date)` and uses `carb_g`, `prot_g`,
  `fat_g`, `tdee`, `session_kcal`, `mode` as given. No twin contains a macro formula.
- **T-2 · Back-fill the week from the deployed engine when the app has not.** Before the context is built for
  anchor day `t`, the Sunday-start week containing `t` is checked; for every date without a row the deployed
  `calculate-daily-macros` function (edge constant `MACROS_FN = calculate-daily-macros-v6`; the prototype calls the
  unversioned name — D-015) is called ONCE for the missing days with the same payload shape the Flutter app builds
  (`daily_macro_service.dart` parity: session duration fallbacks via pace/speed, sport mapping `other → strength`,
  default zone split 70/20/10, yesterday/tomorrow context, `weekly_hours_ratio` when the profile has
  `typical_weekly_hours`), and the result is upserted on `(user_id, target_date)`.
- **T-3 · No profile, no fill.** Without `users.weight_pounds` nothing is computed; the context then carries
  "no target for today" and day guidance uses `minCarbsG = 0`.
- **T-4 · Fail open, back off.** A failed fill is logged and not retried for 10 minutes per `(user, week)`;
  the turn proceeds on whatever rows exist. A turn is never blocked on the macros service.
- **T-5 · Targets are minimums in every rendering.** The persona quotes them as "at least Ng" and never as a
  ceiling; the design family carries the same rule (plan-tab target line).

## Derived quantities Vana adds (owned here, not by Engine B)

| Field | Formula | Where used |
|---|---|---|
| `planningKcal` | `max(0, round(tdee) − round(session_kcal))` — the energy the workout formulas do not already cover | TARGETS line, `DayTarget` |
| `lunchDinnerKcal` | `round(planningKcal × 0.55)` — assumption: breakfast ≈ 25 %, snacks ≈ 20 % | TARGETS line |
| `raceWeekCarbsG` | `max(carb_g)` over the three dates strictly before the race date, else null | TARGETS "race-week ≥NC" |

**The 0.55 / 25 / 20 split is a Mealvana design choice with no citation** (code comment: "documented,
adjustable"). **⚖️ interim (Lee, 2026-09-03)** — Q-DT1 open.

## Conformance

No vectors: T-2's arithmetic is Engine B's, already vectored in `docs/ssot/vectors/daily-macros/`. What this file
gates is a *seam* test (the ship-bundle rule): the payload `ensureWeekTargets` posts must parse as a valid
`calculate-daily-macros` week request — covered today only by the smoke (`scripts/smoke-vana.test.ts`) against
dev. The derived quantities are pending extraction into a pure function (Q-AC1) before they can be vectored.
