# SSOT — Daily Macros: Platform Data Resolution (Garmin / TrainingPeaks / Final Surge)

**Status: RATIFIED v1 (Xuan, 2026-08-14).** Recorded 2026-07-28; Source: Notion
`daily_macro_calc_iteration5_spec` (Formulas 22–27). **Engine:** B. **Conformance target:**
`calculate-daily-macros/formulas/resolve.ts` (name match only — not yet diffed).

## The rule
> Measured beats planned; planned beats estimated. Where a device or a coaching platform actually
> knows a number, that number is used instead of our formula — but the calculation itself never
> changes.

**Iteration 5 adds no nutritional formulas.** Every formula in Iterations 1–4 is untouched. What
changes is *where inputs come from*. The architectural commitment stated by the SSOT: **the
pipeline never asks "is Garmin connected?"** — it receives already-resolved values and produces the
same output regardless of origin, which is what makes it testable without platform mocks.

## Available platform data

### Garmin activity (per completed session, Activity API — `RETROSPECTIVE` only)
| Field | Garmin API field | Replaces |
|---|---|---|
| `garmin_session_kcal` | `ActiveKilocalories` | `sessionCost()` |
| `garmin_avg_hr` | `AverageHeartRateInBeatsPerMinute` | can derive IF if TP unavailable — **derivation unspecified**, see [Q-010](OPEN-QUESTIONS.md#q-010) |
| `garmin_duration_sec` | `DurationInSeconds` | planned duration |
| `garmin_sport_type` | `ActivityType` | cross-check on sport |

### Garmin daily summary (Health API, once per day after sync)
| Field | Garmin API field | Replaces |
|---|---|---|
| `garmin_daily_active_kcal` | `ActiveKilocalories` | the NEAT formula (NEAT = this − session kcal) |
| `garmin_daily_bmr_kcal` | `BmrKilocalories` | Cunningham / Mifflin-St Jeor RMR |
| `garmin_daily_total_kcal` | `TotalKilocalories` | cross-check only |
| `garmin_weight_kg` | Body Composition | athlete weight (Index scale) |
| `garmin_body_fat_pct` | Body Composition | LBM / FFM derivation |

### TrainingPeaks / Final Surge
| Field | Source | Mode | Replaces |
|---|---|---|---|
| `tp_planned_IF` | planned workout | `PROSPECTIVE` | zone distribution → IF |
| `tp_planned_TSS` | planned workout | `PROSPECTIVE` | `duration × IF² × 100` |
| `tp_planned_duration_hr` | planned workout | `PROSPECTIVE` | user-entered duration |
| `tp_actual_IF` | post-workout analysis | `RETROSPECTIVE` | planned IF |
| `tp_actual_TSS` | post-workout analysis | `RETROSPECTIVE` | planned TSS |
| `tp_tomorrow_planned` | tomorrow's calendar | `PROSPECTIVE` | manual tomorrow flag |
| `tp_CTL` | performance chart | both | weekly hours → volume tier |
| `tp_ATL` | performance chart | both | `weekly_load_ratio = ATL / CTL` |

No new user-facing input: the athlete authorizes once via OAuth, and every existing manual input
remains as a fallback.

---

## Formula 22 — `resolveSessionData(session, mode, garmin_activity, tp_data)`

Per session, each variable resolves down its own priority ladder:

```
SESSION KCAL
  RETROSPECTIVE and garmin ActiveKilocalories present  → Garmin        [GARMIN]
  else                                                 → sessionCost() [FORMULA]

IF
  RETROSPECTIVE and tp actual_IF present               → TP actual     [TP_ACTUAL]
  elif tp planned_IF present                           → TP planned    [TP_PLANNED]
  else                                                 → zoneDistributionToIF()  [ZONE_DIST]

TSS
  RETROSPECTIVE and tp actual_TSS present              → TP actual
  elif tp planned_TSS present                          → TP planned
  else                                                 → duration_hr × IF² × 100

DURATION
  RETROSPECTIVE and garmin DurationInSeconds present   → garmin / 3600
  elif tp planned_duration present                     → TP planned
  else                                                 → session.duration_hr
```

**If `kcal_source` is `FORMULA`, session kcal is recomputed with the *resolved* IF and duration** —
not the originally submitted ones. Ladders resolve independently and per session, so a day can mix
sources (session 1 `GARMIN`, session 2 `FORMULA`).

Note the asymmetry the ladders create: in retrospective mode with Garmin, **session kcal is
measured while carb demand is still modelled** — carb demand always runs Formula 5 on the resolved
IF and duration. This is why a large Garmin-vs-formula kcal gap moves fat and TDEE a lot while
barely moving carb.

---

## Formula 23 — `resolveNEAT(...)`

```
if RETROSPECTIVE and garmin_daily.ActiveKilocalories present:
  neat   = max(garmin_daily.ActiveKilocalories − session_kcal_total, 0)   # negative guarded
  source = GARMIN
else:
  neat   = calculateNEAT(rmr, volume_tier, day_mod, lifestyle)            # Iteration 3
  source = FORMULA
```

The clamp at 0 handles the real timing case where the daily summary lags the activity, making
daily active kcal *lower* than the session it should contain.

| Mode | Garmin daily | session kcal | NEAT | source |
|---|---|---|---|---|
| `RETROSPECTIVE` | 1200 | 820 | 380 | `GARMIN` |
| `RETROSPECTIVE` | 700 | 820 | **0** (clamped) | `GARMIN` |
| `RETROSPECTIVE` | null | 820 | 378 (formula) | `FORMULA` |
| `PROSPECTIVE` | connected | — | 378 (formula) | `FORMULA` — always |

---

## Formula 24 — `resolveRMR` → see [`rmr.md`](rmr.md)

---

## Formula 25 — `resolveTomorrow(tp_data, manual_tomorrow)`

```
manual_tomorrow present           → manual values                            [MANUAL]
elif tp_data.tomorrow_planned     → { tss, duration_hr, is_race } from TP   [TP_CALENDAR]
else                              → null (no pre-load)
```

**Manual wins over TP when both are set — RULED (Xuan, 2026-08-13), reversing the recorded
order.** `tomorrow` is a *declaration*, not a measurement: an athlete who explicitly marks
tomorrow a race must not lose to a calendar sync missing the flag. Consistent with Q-005 (the
engine never silently overrides an athlete's setting). Measured *numbers* stay platform-first;
declarations are athlete-first. *(The source Notion page records the old order — push-back
needed.)*

## Formula 26 — `resolveWeeklyRatio(tp_data, manual_ratio)`

```
if ATL and CTL present and CTL > 0 → ATL / CTL          [TP]
else                               → manual_ratio or 1.0 [MANUAL]
```

The `CTL > 0` guard is explicit: CTL = 0 falls back to manual rather than dividing by zero.
CTL 70 / ATL 85 → 1.21.

## Athlete profile auto-update

If Garmin body composition supplies weight or body-fat percentage, the athlete profile is updated
and the new values propagate through **everything** weight-dependent: baseline macros, session
cost, carb demand, LBM/FFM, the fat floor and both clamps. Example: weight 74.2 kg with BF 15.5 %
→ LBM 62.7 → protein base `1.8 × 62.7 = 113 g`.

**Raw propagation accepted as-is (Xuan, 2026-08-13).** Smoothing (e.g. 7-day rolling weight) was
considered and deliberately not adopted for now; revisit only if scale-user targets visibly
oscillate.

**Manual profile edits — which cached days recalculate — RULED (Xuan, 2026-08-17,
post-ratification addition; [Q-016](OPEN-QUESTIONS.md#q-016)).** The policy is
**source-independent**: it covers any MANUAL write to an engine input (weight, height, body-fat
percentage, lifestyle, typical weekly hours, carb-cycle opt-in, training phase — Settings is
merely the surface). On such a write, **today's and future cached daily plans are invalidated and
recalculated with the new values; past days are never touched** — a delivered plan is the
historical record of what the athlete was told to eat, and recalculating it would retroactively
flip "hit your target" verdicts. Consistent with the "today is for today" ruling (F27) and with
the Garmin rung above, which likewise updates the profile *before* today's computation, never
history. The spec owns this policy; the app owns the mechanism (cache invalidation — cf. the
activity-change window in `macro_cache_invalidation.dart`). Raised via intake:
`intake/2026-08-17-manual-input-change-invalidation.md`.

---

## Formula 27 — `recalculateAfterSync(...)`

Re-runs the full pipeline in `RETROSPECTIVE` mode and reports the movement for the UX:

```
retro_plan = dailyMacros_v5(..., mode = RETROSPECTIVE, garmin_activity, garmin_daily, tp_actual)

delta = {
  carb:         retro.carb_g       − prospective.carb_g,
  prot:         retro.prot_g       − prospective.prot_g,
  fat:          retro.fat_g        − prospective.fat_g,
  tdee:         retro.tdee         − prospective.tdee,
  session_kcal: retro.session_kcal − prospective.session_kcal,
}

return { plan: retro_plan, delta, sources: retro_plan.sources }
```

**The retro plan replaces today's plan, including the remaining day — RULED (Xuan, 2026-08-13).**
"Today is for today": after sync, the athlete's live targets are the retrospective ones, even when
that shrinks mid-afternoon numbers they were eating toward. Known cost, accepted for this
iteration; `plan_recalc_log` (above) captures `local_sync_time`, the delta, and the EA status
transition precisely so the next iteration can assess how disruptive this is in practice before
designing a softer landing. Display note: a post-sync shrink can flip net-balance copy to
"surplus" through no action of the athlete's — the intraday-display suppression rules apply to
`pre_override` only, so this transition is the first candidate the log data should examine.

**A skipped workout is a first-class case — with a confirmation rung (RULED, Xuan, 2026-08-13):**
"no sync" and "didn't happen" are different facts, and the athlete is the tiebreaker. The
retrospective ladder for an unsynced session:

```
garmin activity synced                     → measured values             [GARMIN]
elif athlete confirmed "workout done"      → FORMULA values at the resolved IF/duration  [MANUAL]
else                                       → rest day (session_kcal = 0, carb ≈ baseline)
```

**Soft delete + sync matching — RULED (Xuan, 2026-08-14).** Activity deletion sets
`status = 'deleted'`; the row persists. **The sync import matcher MUST match against deleted rows
too** — an incoming platform activity that matches a tombstone is dropped, not re-imported. A
matcher that filters `status != 'deleted'` before matching reintroduces the exact bug the
tombstone exists to prevent (deleted workouts reappearing after every sync). Display side:
`intraday-display.md` §4b.

**The match key — RULED (Xuan, 2026-08-14).** "Matches" means, in priority order:

```
1. platform activity id equal            (where the platform supplies one — Garmin/TP do)
2. else: same platform AND same sport AND start time within ±15 minutes
```

The fallback exists for platforms/paths without stable ids; the ±15 min window is `[design]`
(wide enough for device-clock skew, narrow enough that a genuine second session survives). The
same key governs BOTH tombstone matching and ordinary re-sync dedup — one definition, two
consumers, so they cannot drift.



**Two time fields per workout — RULED (Xuan, 2026-08-14).** Every session row carries
`planned_time` and `actual_time` (nullable), and they are never conflated:

```
planned_time : set at scheduling; the swipe gesture NEVER writes it
actual_time  : written by Garmin sync (activity start), OR by mark-done (= now);
               CLEARED by mark-undone (back to null — the card shows planned_time again)
```

Display rule: a card shows `actual_time` when present, else `planned_time`. Consequences the
implementer must honour: marking a 5:30 PM workout done at 3:00 PM moves it to 3:00 PM on the
timeline (it really happened now, or the athlete says it did); `workout_so_far` in the intraday
display keys off `actual_time` presence, never off `planned_time` having passed; and a later
Garmin sync overwrites a mark-done `actual_time` with the measured start (`MANUAL → GARMIN`
upgrade, same as the kcal path). Supabase carries both columns on the workout row.

The confirmation is a first-class input (home-page affordance — see the design prompt in the
reconciliation worklist), so a dead watch or delayed sync never silently strips a real workout's
fuel from the plan. A later Garmin sync for a confirmed session upgrades `MANUAL → GARMIN` and
re-runs the recalc.

**`SKIPPED` — the athlete's "didn't happen" as a first-class write — ADDED (RATIFIED Xuan, 2026-08-17, post-ratification addition shipping in
`daily-macros-dashboard@v2`; design contract `spec/design/components/workout-card.md` Q-D6).** The ladder above is unchanged; this names how a workout
lands on its third rung *before* the day is over. The workout row's `status` gains `skipped`
(alongside the `deleted` tombstone): written by the athlete's Skip on the card — allowed on the
current day — cleared by Unskip or by mark-done. A `status = 'skipped'` session contributes
**zero** to the day's session demand and fuel windows exactly as the else-rung does, even while
`planned_time` is still in the future. Passive skip (day past, `actual_time` null, not
`skipped`) is **derived**, never written. **Sync beats skip:** the Garmin rung sits above both — a
platform activity matching a skipped row (same match key as above) upgrades it to measured values
and clears `skipped`; the matcher MUST NOT filter `status = 'skipped'` rows out before matching,
for the same reason it must not filter tombstones. Delete (`status = 'deleted'`) is deferred to a
future bundle; the tombstone rule stays as written.

---

## Worked end-to-end example (verified)

Reference athlete, 90-min run, `BASE`, ratio 1.0, Garmin + TP connected, Garmin daily
`ActiveKilocalories = 1200`:

| Variable | Prospective (morning) | Retrospective (post-sync) | Source change |
|---|---|---|---|
| RMR | 1908 (Cunningham) | 1920 (Garmin BMR) | `FORMULA → GARMIN` |
| Session kcal | 1205 (formula, IF 0.74) | 892 (Garmin measured) | `FORMULA → GARMIN` |
| IF | 0.74 (TP planned) | 0.76 (TP actual) | `TP_PLANNED → TP_ACTUAL` |
| Carb demand | 69 g | 74 g | recalculated from IF |
| NEAT | 378 (formula) | 308 (= 1200 − 892) | `FORMULA → GARMIN` |
| TEF | 387 (iterative) | 346 (iterative) | always `FORMULA` |
| **carb** | 369 | 374 | +5 |
| **prot** | 130 | 130 | unchanged |
| **fat** | 209 | 161 | −48 |
| **TDEE** | 3878 | 3466 | −412 |

Cross-checks: retro TDEE = `(1920 + 308 + 892) / 0.9 = 3466.7` ✓ (fat above floor, so the closed
form applies); retro fat = `(3466 − 1496 − 520) / 9 = 161.1` ✓; retro carb = `300 + 73.5` where the
IF-0.76 rate is `40 + 0.6 × 15 = 49 g/hr` over 1.5 hr ✓.

**The insight the SSOT draws from this**: measured session cost (892) is far below the formula
estimate (1205), which drops TDEE by 412 kcal. Carb barely moves — it keys off IF, not kcal — but
fat, the residual, absorbs almost the whole difference.

### Garmin-first affirmed, with mandatory calibration logging — RULED (Xuan, 2026-08-13)

**The ladder stands: Garmin session kcal wins where present.** The device is on the athlete's
wrist for the actual session; it is the most trustworthy signal we have. But the question of *how
much* better it is than the formula has never been measured on our own population — Garmin
`ActiveKilocalories` is itself a model — so **any correction (damping, blending, capping the
formula-vs-Garmin delta) is deliberately deferred until we have data, and collecting that data is
a requirement of this spec, not an optional nicety:**

Every `recalculateAfterSync` run MUST persist one row to `public.plan_recalc_log` (Supabase,
`plan_generation_log` pattern: append-only, RLS enabled with no policies, service-role writes):

```sql
create table if not exists public.plan_recalc_log (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  device_id    text,
  local_sync_time time,       -- time-of-day the recalc landed (ruling 5's question)
  sessions     jsonb,         -- [{sport, duration_hr, resolved_if,
                              --   formula_kcal, garmin_kcal, kcal_source}]
  delta        jsonb,         -- the F27 delta object, verbatim
  ea_status_before text, ea_status_after text
);
```

`sessions[].formula_kcal` is computed with the SAME resolved IF/duration as the Garmin comparison —
the pair must be like-for-like or the calibration is noise. Evaluation question, recorded now so
the analysis answers it: *what is the distribution of `garmin_kcal − formula_kcal` by sport and
duration, and does the resulting fat/TDEE swing (ruling 5) warrant a correction?*

## Regression requirement

With `garmin_connected = false` and `tp_connected = false`, output must be **identical to
Iteration 4** for the same inputs, and no `GARMIN` or `TP*` source tags may appear anywhere in the
output. Every Iteration 1–4 case must still pass unchanged.

## `sources` object — RULED (Xuan, 2026-08-13, [Q-012](OPEN-QUESTIONS.md#q-012))

Must carry a source tag for: `rmr`, `neat`, `session_kcal` (array, one per session), `IF` (array,
one per session), `tomorrow`, `weekly_ratio`.

**The tag enum is pinned to exactly seven values:**
`GARMIN` · `TP_ACTUAL` · `TP_PLANNED` · `TP_CALENDAR` · `ZONE_DIST` · `FORMULA` · `MANUAL`.
The bare `TP` that appeared for the weekly ratio was inconsistent naming, not an eighth source —
it **normalises to `TP_PLANNED`**. A tag outside the enum is a conformance failure.

### Display mapping — sources enum → athlete-facing chips (F-13, PROPOSED 2026-08-13)

The dashboard renders the seven tags as four chips. The mapping is **total** — a chip the enum
cannot produce, or a tag with no chip, is a conformance failure. `[design]`, awaiting ratification
with this file:

| Tag | Chip |
|---|---|
| `GARMIN` | `verified · Garmin` |
| `TP_ACTUAL` | `verified · TrainingPeaks` |
| `MANUAL` | `self-reported` |
| `TP_PLANNED`, `TP_CALENDAR` | `planned (estimate)` |
| `FORMULA`, `ZONE_DIST` | `estimated` |

Rationale: *verified* = a platform measured it after the fact; *planned* = a human scheduled it;
*estimated* = we computed it. `ZONE_DIST` is a computation over athlete-entered buckets, hence
*estimated*, not *self-reported* — the athlete reported the zones, not the number shown.

**`delta` is `null` on every path except retrospective recalculation** (`recalculateAfterSync`),
where it carries the shape defined above. Not absent, not zeros — `null`, so a consumer can
distinguish "no recalculation happened" from "recalculation happened and nothing moved".

## Deferred by the SSOT (explicitly, not oversights)
- **CTL staleness detection** — a CTL over 30 days old is used anyway; deferred to "v2.1".
- **HR-derived IF — RULED deferred (Xuan, 2026-08-13, [Q-010](OPEN-QUESTIONS.md#q-010)),** like
  CTL staleness. `garmin_avg_hr` is collected but unused; the IF ladder falls from `TP_PLANNED`
  straight to `ZONE_DIST`, and the edge case ("TP IF takes priority over Garmin HR-derived IF") is
  vacuously satisfied. If the rung is ever added it slots between `TP_PLANNED` and `ZONE_DIST` and
  requires its own derivation spec first — an implementer must NOT invent one.
