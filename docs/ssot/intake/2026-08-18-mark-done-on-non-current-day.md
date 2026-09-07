> **RESOLVED 2026-08-18 → Q-D7 / Q-018 RULED (`actual_time = planned_time` on past + current days; no mark-done on a future day). CONTRACT CHANGE (class c) — folded on v3 terms (workout-card v3 / platform-resolution two-time v2 / gestures manifest v3, all STAGED awaiting ratification of the written text) and vectors regenerated (`two-time-mark-done` 900→1050, +2); ships as `daily-macros-dashboard@v3` via ship-bundle, not a @v2.1 point tag. App handback: `intake/2026-08-18-handback.md`.**

type: ruling-request
bundle: daily-macros-dashboard@v2

> **RULED BY THE SPEC OWNER (Xuan, 2026-08-18) — decision recorded below; awaiting the fold.**
> **App implemented AHEAD of the fold** on `feature/daily-macro-dashboard-redesign` (commit noted in
> the app README ledger) with tests pinning the ruled behaviour. If the fold changes anything below,
> the app side re-syncs and adjusts; nothing here is authorization by implementation.

## Why this matters
Found on-sim 2026-08-18: marking a workout done from a day OTHER than today made the card vanish
from that day. G1 as ratified writes `actual_time = now`; the surface places a card on
`actual_time ?? planned_time`; so a workout on tomorrow (or yesterday) jumped to today's timeline —
and, on the past-day case, into today's `workout_so_far`. Nothing in v2's contract or tests
considers G1 on a non-current day (every g1 pin is same-day). Blocks: honest intraday figures and
the passive-SKIPPED recovery path (G1 on a past day) until ruled.

## The question
What does G1 (mark done) write for `actual_time`, and is it offered at all, when the card's day is
not the current day?

## What is already ruled (v2)
- `spec/design/components/workout-card.md` G1: `actual_time = now` (W-7 ruling); "card moves to
  the current time on any time-ordered surface".
- `spec/daily-macros/platform-resolution.md` two-time model: "actual_time: written by Garmin sync
  (activity start), OR by mark-done (= now)"; worked consequence "marking a 5:30 PM workout done at
  3:00 PM moves it to 3:00 PM".
- `conformance/design/macro-dashboard.gestures.yaml` `g1_swipe_right_marks_done`: "actual_time
  written = now; card moves to current time on the timeline".
- Q-D6 recovery: G1 on SKIPPED (past day) → DONE_CONFIRMED, `actual_time = now`.
All of it was written with the current day in mind; none names the cross-day case.

## The decision (Xuan, 2026-08-18)
1. **Past day:** mark-done does NOT move the workout. `actual_time = planned_time` — the common
   case is yesterday's session that never synced and the athlete confirms it happened as planned.
   Applies equally to G1 recovery of a passive-SKIPPED card: it stays on its day, at its slot.
2. **Future day:** mark-done is NOT offered. Tomorrow hasn't happened; an athlete who does
   tomorrow's session today creates today's workout and skips tomorrow's. The card takes no
   right-swipe (token nudge, no reveal — the G3 treatment); Skip (G4/G5) remains available;
   mark-UNDONE remains available on a (legacy) confirmed future card so it can be corrected.
3. **Current day — the deliberate contradiction with W-7:** `actual_time = planned_time` here too.
   The confirmation is "it happened as planned", not a timestamp of the confirmation; a swipe made
   hours after the session should not relocate it on the timeline. If a sync later arrives, the
   measured start still overwrites (MANUAL → GARMIN) exactly as before. Consequence for
   `intraday-display.md §1`: `workout_so_far` already keys off `actual_time` PRESENCE, not clock
   position, so a session marked done before its planned time still counts in full — unchanged.
   The one visible change: a card marked done no longer slides to "now"; it stays at its planned
   slot with the self-reported chip.

## What the fold touches (for apply-ruling)
- `workout-card.md` G1 row + the W-7 sentence; G3-style suppression line for future days
  (probably its own row or a G1 clause); Q-D6 recovery sentence ("actual_time = now" → planned).
- `platform-resolution.md` two-time model: "mark-done (= now)" → "(= planned_time)"; the 5:30→3:00
  worked consequence flips (the card stays at 5:30 PM).
- `macro-dashboard.gestures.yaml`: `g1` assertions ("= now" → "= planned_time; card keeps its
  slot"), a new negative row for future-day suppression, `skipped_swipe_right_recovers`
  ("actual_time = now" → planned).
- Feature test plan: I2 wording ("actual_time is null unless Garmin or mark-done wrote it" holds).
- Vectors: `platform-resolution.json` `two-time-mark-done` DOES pin `= now` (inputs
  planned 1050 / now 900 → expected actual 900, display 900). Regenerate to actual 1050 /
  display 1050 ("mark-done writes actual_time = planned_time"). The app-side twin the runner
  exercises (`supabase/functions/_shared/workouts/workout-times.ts` `applyMarkDone`) is
  deliberately left at `= now` until that regeneration lands, so the ratified vector stays green
  and the two flip together — the production write path (Dart repository) already implements the
  ruling; the twin is test-only.
Amendment in place (dated fold, re-tag `@v2.1`) vs `@v3` is QA's classification call; the app
side needs only a re-sync of the mirror either way.

## App-side state (implemented ahead)
- `ActivitiesRepository.markWorkoutDone`: `actual_time = planned_time ?? scheduled_date_time`
  (an explicit `at:` still wins for callers that know the real start); controller optimistic
  update matches.
- `WorkoutCardData.markDoneAllowed` (false on a future day) → card suppresses the right-swipe
  for planned/skipped; undone and skip unaffected.
- Tests: gestures suite (future-day suppression; two-time write = planned), repository seam on a
  real Drift DB, screen-level "a workout confirmed on another day never leaks onto this day",
  Patrol flow asserts `actual_time == planned_time`.

## Gates
Nothing else app-side. QA: the fold + manifest wording so `land-bundle`'s audit and the tests
agree again before the bundle lands.
