# SSOT — Week Character

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** N/A — recorded from the shipped code (see Code).
**Code:** `deriveWeekCharacter(activities, macros)` — prototype `lib/derive-week-character.ts` ≡ edge
`_shared/vana/derive-week-character.ts` (byte-identical). No Dart twin (the client never derives it).
**Scope:** load score · character band · anchor session · race-week detection. **Consumers:** the CONTEXT
`WEEK` line, `weekContexts()` (selection), the opener's salience order.

## Inputs

| Field | Type | Notes |
|---|---|---|
| `activities[]` | `{scheduled_date_time, title, activity_type, duration_minutes, intensity_level, distance_*}` | the athlete's rows from anchor day through anchor + 7, non-deleted |
| `macros[]` | `{target_date, carb_g}` | the first 7 `daily_macro_targets` rows from the anchor day |

## Constants

```
INTENSITY_WEIGHT = { low 1, easy 1, moderate 2, mod 2, high 3, threshold 3.5, vo2max 4, race 5 }
DEFAULT_WEIGHT   = 2          # missing or unknown intensity_level
RACE_PATTERN     = /race|marathon|half|10k|5k|ironman|tri\b/i     # tested on `${title} ${activity_type}`
BAND_HIGH        = 1200       # totalLoad >  1200 → high-load training
BAND_MODERATE    = 600        # totalLoad >   600 → moderate training
WINDOW_DAYS      = 7          # activities dated ≤ today + 7 count
```

## The algorithm

```
thisWeek   = activities where date(scheduled_date_time) <= today + 7
totalLoad  = Σ duration_minutes × weight(intensity_level)
workoutDays = |distinct dates in thisWeek| ; restDays = 7 − workoutDays
anchor     = the longest session (stable sort by duration desc; ties keep input order)
isRaceWeek = any activity whose "title type" matches RACE_PATTERN

character  = isRaceWeek ? "race week"
           : workoutDays == 0 ? "full rest"
           : totalLoad > 1200 ? "high-load training"
           : totalLoad > 600  ? "moderate training"
           : "easy / recovery"
avgCarbG   = round(mean(macros.carb_g)) or 0 when no rows
```

Headline / CTA strings and `anchorDayName` are also emitted; they are copy, screenshot-held, not contracted here.

## Invariants (conformance must assert)

1. `character ∈ {race week, full rest, high-load training, moderate training, easy / recovery}` — exactly five.
2. `isRaceWeek ⇒ character == "race week"` regardless of load.
3. `workoutDays + restDays == 7`; a double day is one workout day (`two-sessions-one-day`).
4. `totalLoad` is exact integer arithmetic (rounded at return only — every weight × minutes here is integral or
   a half; `threshold` 3.5 can produce a .5 that `Math.round`s).
5. The anchor is by **duration**, never by intensity (`high-load-band`: the 240-min ride beats the threshold run).
6. Intensity labels outside the table weigh 2 (`unknown-intensity-weight-defaults-to-2`).

## Worked examples

See the vectors — the ten cases are the full decision surface. Two are tripwires:

- **`triathlon-word-is-not-a-race` (characterization).** "Olympic triathlon", `intensity_level: race`, 150 min
  → **moderate training**: `tri\b` fails on "triathlon" and `intensity_level` is never consulted. → **Q-WC2**.
- The classifier is volume-weighted: one 60-min interval session is an "easy / recovery" week. → **Q-WC1**.

## Deviations

None between twins (byte-identical). Open questions: Q-WC1, Q-WC2, Q-WC3 (the race signal from a title is not
joined to the `events` row that drives carb-load tags — see `../selection/meal-suggestion.md`).

## Conformance

Vectors: `vectors/planning/week-character.json` (10) — `run_edge.sh` + `run_prototype.sh`. Both green
2026-09-03. Required coverage: every band boundary from both sides (600/601, 1200/1201 — **not yet vectored**,
add when ratified), the race pattern on title and on type, the distinct-day rule, the default weight.
