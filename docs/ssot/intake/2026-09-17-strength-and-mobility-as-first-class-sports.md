type: ruling-request
bundle: daily-macros-dashboard (session-demand F4a follow-through) + data-integrations@v1
filed: 2026-09-17 by Xuan (live test on prod 1.27.0+113) — root-caused from code + prod data
severity: Major — under-fuelling, not cosmetic

# Strength & mobility as first-class activity types

## The gap in one sentence
**The app cannot express a sport its own engine already prices**: `ActivityType` has no
`strength` and no mobility member, so every strength session is imported as `other`, and
F4a then prices unknown sports at **exactly 0 kcal** — while `SESSION_BASE_RATE.strength`
and `carbDemand`'s dedicated strength branch (27 g·h⁻¹) sit unused in
`calculate-daily-macros-v6/formulas/session.ts`.

## Evidence

### E1 — Synthetic test: TrainingPeaks strength (2026-09-17)
A TP **Strength** workout was created on Lee's calendar (45 min, no distance) and synced to
Xuan's prod account (1.27.0+113).

| Field | Value | |
|---|---|---|
| `activity_type` | `other` | correct per 2e3b247c — the enum has nothing better |
| `distance_miles` | **2.99998** | INVENTED — `TrainingPeaksDefaults.runningDistanceMeters` (4828 m) |
| displayed pace | **15:00 /mi** | INVENTED — `_calculatePace(45 min ÷ invented 3 mi)` |
| timeline icon | running glyph | `workout_card.dart:374` `_sportIcon` `_ => Icons.directions_run` |
| detail hero | photograph of a runner | |
| engine session kcal | **0** | F4a ESTIMATE_ZERO for unknown sports |

Screens: `assets/2026-09-17-strength-timeline-run-icon.png` (the Foam Rolling row above it
also prints the raw enum string "other" as its subtitle),
`assets/2026-09-17-strength-detail-3mi-15min-pace.png` ("3.0 mi · 45m · 15:00 /mi" above a
**Generate Plan** button).

### E2 — Live device test: Garmin strength (2026-09-17, Xuan)
Xuan started a Garmin **strength** workout and stopped it after seconds.
Screen: `assets/2026-09-17-garmin-strength-run-icon-0min.jpg` (circled row, 11:23 AM).

| Field | Value |
|---|---|
| `activity_type` | `other` ✅ |
| `distance_miles` | **null** ✅ — the Garmin path does NOT invent one |
| title | "Strength" (renders truncated as "STRE…") |
| icon | **running glyph** ❌ |

**This isolates the two defects cleanly: the fabricated distance/pace is
TrainingPeaks-path-only (`_getDistanceMeters`); the running icon lies on BOTH paths.**

### E3 — The real-world case: Coach Claudia, Friday 2026-09-04
Claudia's own report (`assets/2026-09-04-claudia-strength-shown-as-run-no-title.png`), in
her words: *"it always shows 'run' even though Friday was a strength session and I did have
a planned 3 x 5 min tempo ride in TP but did strength instead. But not sure why it shows
2 x here."*

**Was it really strength?** Yes — the raw Garmin payload (prod `garmin_health_data`,
`activity_raw` + `activity_detail_raw`, 2026-09-04) is unambiguous:

| Field | Value |
|---|---|
| `activityType` | **`STRENGTH_TRAINING`** |
| `durationInSeconds` | 2912 (48.5 min → her "49 min") |
| `activeKilocalories` | 178 |
| `distanceInMeters` | **null** |
| `steps` | **6** |
| `averageHeartRateInBeatsPerMinute` | 93 |

Six steps, HR 93, no distance. Her actual runs that week: 47 min → 5.51 mi / 464 kcal;
51 min → 6.02 mi / 516 kcal; 43 min → 5.01 mi / 426 kcal.

**Her stored row was ALWAYS correct** (`activity_type: other`; so are her Elliptical,
Pilates and other Strength rows, going back to 2026-09-02 — well before 1.27.0). Nothing
in the DATA was ever wrong. **The only thing that told her "run" was the icon.** The
2026-09-10 type-mapping fix (2e3b247c) therefore does NOT address her complaint; the
`_sportIcon` fallback is the whole of it.

**Aggravating factor (Xuan, 2026-09-17):** on her 1.26.0 build the card carried **no title
at all** — just a running glyph and "49 min" (compare E2, where 1.27.0 shows a truncated
"STRE…"). With no title, no distance and a running icon, a strength session is
*indistinguishable* from a run. Worth confirming whether the card header changed between
1.26.0 and 1.27.0; either way the icon must not be a sport the athlete did not do.

**Why "2 x"?** Not a duplication bug. Two genuinely distinct TP workouts were planned that
day — `3930489194` "3 x 5 Min tempo ride" (scheduled **00:00**, no time) and `3930491565`
"Free ride" (07:00). But BOTH display "10.0 mi · 45 min": `9.99972` mi is
`TrainingPeaksDefaults.cyclingDistanceMeters` (16093 m) — **we invented the same distance
for both**, which is what makes them read as clones of each other. Her confusion is our
fabrication plus a missing scheduled time, not a double import.

**And the third thread she felt but could not name:** her strength session could not
complete either planned ride, because the matcher refuses to match any activity whose sport
is `other` (matching.md M-1 gate 1a). So she was left with a completed strength session and
two orphaned "Skipped" rides. One ruling closes all three of her threads.

## Why this is Major
1. **Athletes are under-fuelled for strength work.** Zero kcal and zero carb demand for
   every lifting session. Coach Claudia lifts; her athletes lift.
2. **The numbers on screen are fabrications**, not absences — a 3-mile run at 15:00/mi
   that never existed. `_getDistanceMeters`'s `other` branch justifies itself with
   *"never generates a nutrition plan, so this value is display-only"*; both halves of
   that premise are false today.
3. **It is very likely the root of Claudia's duplicate-workout complaint.** The matcher
   refuses to match any activity whose sport is `other` (matching.md M-1 gate 1a), so her
   Garmin strength session could not complete her planned session and she got two rows.
   If strength becomes a real type, that match becomes possible on its own merits — one
   ruling would close three of her reports (mislabel, duplicate, and the 0-kcal fuelling).

## The questions to rule

**Q1 — Add `strength` to `ActivityType`?**
The engine already prices it. Recommended: yes.

**Q2 — Add a mobility member (F4a's class: foam rolling / stretching / yoga / aqua-routine)?**
F4a ruled MOBILITY at 2.5 kcal·kg⁻¹·h⁻¹ linear in IF, and the edge fn implements
`MOBILITY_SPORTS` — but the app can only send `other`, so that rate is also unreachable.
Options: (a) a single `mobility` member; (b) keep mobility inside `other` and let the
server classify by title; (c) mobility member now, richer taxonomy later.

**Q3 — What may a non-distance sport display?**
Recommended: nothing invented. No distance, no pace, no running imagery — duration only.
This also means `_getDistanceMeters` must be allowed to return null (the field is
currently non-nullable, which is *why* the running default exists). Note E2: the **Garmin
path already does the right thing** (leaves distance null), so this is specifically about
bringing the TP path into line with it — there is a working precedent in-repo.

**Q4 — Does an unknown/`other` sport still get a fuel plan offered?**
Today the detail screen offers **Generate Plan** for a session the engine prices at 0.
Options: offer it (protein/recovery framing), hide it, or gate on the ruled class.

**Q5 — Icon/copy fallbacks.** Both `_sportIcon` switches (`workout_card.dart:374`,
`breakdown_pager.dart:1343`) default unknown sports to `Icons.directions_run` — the same
`_ => running` class F4a removed from the engine and 2e3b247c removed from the type mapper.
Recommended: default to a neutral glyph, never a specific sport. **This single fallback is
the entirety of Claudia's "it always shows run" complaint (E3)** — her data was never
wrong. Also: the timeline subtitle renders the raw enum string `other`; it needs a display
name ("Workout").

**Q5b — Must a workout card always carry its title?** On Claudia's 1.26.0 build the Garmin
strength card showed no title at all (E3), leaving a running glyph and a duration as the
only information — indistinguishable from a run. Should a card without a title be
possible, and should the sport be stated in words wherever the icon is ambiguous?

**Q6 — Matching.** If strength becomes first-class, does M-1 gate 1a admit
strength→strength matches? (Deliberately kept out of scope of the 2026-09-10 ruling,
"revisit after the guard lands".)

**Q7 — Migration.** Existing rows: `other` activities carrying exactly 4828 m of invented
distance, and historical strength sessions typed `other`. Re-type on next sync, backfill,
or leave? (Xuan 2026-09-17: **leave stored rows alone** for now — fix-forward.)

## Gates (what shipping this requires)
- `ActivityType` enum + Drift/Postgres enum alignment (activity_type_enum) — schema change.
- Provider mappers: TP (`training_peaks_transformer`), Garmin, Final Surge.
- Engine payload: send `strength` / mobility so F4a's existing rates are reached; the
  queued **F4a spec-to-vectors regeneration** must cover the new sports (that pass being
  unrun is how the F4a validator gap shipped — see 2026-09-15 incident).
- Display: no invented distance/pace, neutral icons, display names.
- Decide Q6 before touching the matcher.

## Communications note
The 2026-09-15 draft email to Claudia (`ops/emails/2026-09-15-claudia-fixes-and-final-surge.md`)
reports her "shows Run" item as fixed. **Per E3 that is not accurate** — the type mapping was
fixed, but what she saw was the icon, which is still live. Correct that paragraph before the
email is sent.

## Status
FILED, not implemented. Xuan's direction 2026-09-17: intake everything, **patch nothing** —
the display fixes are deliberately NOT being shipped as an OTA patch because they are
entangled with the ratification above. Stored rows left untouched.

## Cross-refs
- `spec/daily-macros/session-demand.md` §F4a (mobility/composite/unknown ruling, 2026-09-10)
- `spec/integrations/matching.md` M-1 gate 1a (the duplicate)
- `spec/integrations/payload-usage-map.md` (TP field disposition)
- App: `2e3b247c` unknown types → other; `ops/data/bug-reports/2026-09-17-strength-displayed-as-invented-run.md`
- Claudia's reports: `ops/emails/2026-09-15-claudia-fixes-and-final-surge.md`
