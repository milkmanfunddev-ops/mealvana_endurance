# Handoff — daily-macros-dashboard@v3 → the coding agent

**Checkout `daily-macros-dashboard@v3`** (commit `180658d`) in the qa repo (resolve via `$QA_ROOT`
from `mealvana_endurance/workspace.env`). The manifest `bundles/daily-macros-dashboard.yaml` is the
index: 13 slices, 7 named exclusions, done_when. Companion documents: the 172 vectors under
`vectors/daily-macros/` (v1/v2 handoffs said 168 — that count was stale; the tags held 170), the
two design manifests under `conformance/design/` (gestures **v3: 18 tests**; goldens v2: 10), the
feature test plan `docs/feature-test-plans/macro-dashboard.md`, and the 2026-08-17 reconciliation
of the prototype, `docs/design-reconciliation/macro-dashboard-2026-08-17-skip-revision.md`.

**v3 supersedes `@v2` (`cf69821`); `@v2` superseded `@v1` (`e2c3fe0`).** v3 carries ONE ruling
— read "What v3 changes" first; everything else below it is the v2 handoff, unchanged and still
binding. Re-sync `$APP_ROOT/docs/ssot` as a verbatim mirror of **`180658d`** and re-pin
`SSOT_SOURCE.txt` to the tag. The itemised checklist for this delta is
`intake/2026-08-18-handback.md` — execute it verbatim.

## What v3 changes (workout-card.md v3, platform-resolution.md v2 — the delta from @v2)

**Q-D7 / Q-018 — RULED and RATIFIED (Xuan, 2026-08-18).** Source:
`intake/2026-08-18-mark-done-on-non-current-day.md` (RESOLVED). Contract change, so `@v3` — an
implementation green against `@v2`'s `g1` / `two-time-mark-done` is RED here by design.

- **G1 (mark-done) writes `actual_time = planned_time` — never `now`.** Reverses W-7 (2026-08-14).
  The confirmation means "it happened as planned", not a timestamp of the swipe; a swipe hours after
  (or before) the session does not relocate the card. Holds on a **past day** (yesterday's unsynced
  session confirmed as planned stays on yesterday, at its slot — nothing lands on today's timeline or
  in today's `workout_so_far`) **and on the current day**. A later Garmin sync still overwrites with
  the measured start (`MANUAL → GARMIN`) — `two-time-sync-overwrites-mark-done` pins it.
- **Mark-done is not offered on a future day.** Right-swipe on a future-day card takes the G3
  treatment (token nudge, no reveal, no write, no state change); Skip/Unskip (G4/G5) still reveal;
  mark-undone (G2) still runs on a (legacy) confirmed future card so it can be corrected. Rule is
  on the card's **day**, not on `planned_time` — a same-day workout is markable before its time
  (`workout_so_far` counts it in full via `actual_time` presence; `intraday-display.md` §1 unchanged).
- **Q-D6 recovery inherits the write:** G1 on `SKIPPED` → `DONE_CONFIRMED`, `actual_time =
  planned_time`, card back at its slot on its own day.
- **Vectors:** `platform-resolution.json` `two-time-mark-done` REGENERATED (planned 1050, now 900 →
  actual 1050 / planned 1050 / display 1050 — was 900/1050/900); NEW `two-time-mark-done-after-planned`
  (now 1200 → 1050); NEW `two-time-sync-overwrites-mark-done` (gesture `sync`, measured 1042 over
  MANUAL 1050 → 1042 / GARMIN). Expect your `@v2` green count **+2, zero red**.
- **Gestures manifest v3:** `g1_swipe_right_marks_done` rewritten (`= planned_time`, `now ≠
  planned_time` on both sides, current + past day, card keeps slot); NEW negative
  `g1_future_day_not_offered`; `skipped_swipe_right_recovers` inherits the write;
  `sync_upgrades_confirmed_to_verified` annotated (unchanged). Map app tests by these ids.
- **Goldens:** no change — no state's visual signature moved; `workout_card_*.png` stand.
- Not in v3 (open, riding later as class-(b) additions or with the integration-sync SSOT):
  `intake/2026-08-18-skipped-row-sync-match-window.md`,
  `intake/2026-08-18-platform-declared-skip-semantics.md` — status quo (= the ratified text) holds.

### v3 conflict watchlist (verified against `$APP_ROOT` 2026-08-18, branch `feature/daily-macro-dashboard-redesign` @ `723719fd`)

**This is an UPDATE of a build that already implements Q-D7 ahead of the fold** (app commit
`723719fd` "mark-done writes actual_time = planned_time; no mark-done on a future day") — verify,
don't rebuild. Verified by grep/file-check:

1. **Production write path already ruled-conformant:** `lib/features/activities/data/activities_repository.dart`
   `markWorkoutDone` (`actual_time = planned_time ?? scheduled_date_time`, explicit `at:` wins),
   surfaced through `activities_service.dart` and `activities_controller.dart:305/319`;
   `WorkoutCardData.markDoneAllowed` in `lib/features/macro_dashboard/domain/dashboard_models.dart`,
   consumed by `dashboard_assembler.dart`, `workout_card.dart`, `macro_dashboard_screen.dart`.
   Check only that `markDoneAllowed` keys off the card's DAY (false for future days), not off
   `planned_time > now`.
2. **The one deliberate red — the test-only TS twin:** `supabase/functions/_shared/workouts/workout-times.ts`
   `applyMarkDone` (L21–26 still `actual_time_min: now_min`, header comment L9 "(= now)") was held at
   `= now` so `@v2`'s vector stayed green. **Flip it now** to `= planned_time_min` (and its header
   comment), and add a `sync` arm to the `two-time` branch of
   `supabase/functions/calculate-daily-macros/vectors.conformance.test.ts` (L557–563 dispatches
   `mark_done`/`mark_undone` only) for `two-time-sync-overwrites-mark-done`. Commit message cites
   Q-D7 / platform-resolution v2. Vector `two-time-mark-done-after-planned` needs no new arm.
3. **Existing tests already pin the ruled behaviour** — `test/features/macro_dashboard/macro_dashboard_gestures_test.dart`
   (future-day suppression; write = planned; L420–430 pins `planned_time` untouched),
   `macro_dashboard_screen_test.dart` ("confirmed on another day never leaks"), repository seam on
   Drift, Patrol flow. Reconcile their names/assertions to manifest v3 ids (`g1_future_day_not_offered`
   is the new required id); no test should still assert `actual_time == now` anywhere.
4. **Adjacent writers of `actual_time` are NOT this ruling's:** Garmin completion
   (`supabase/functions/_shared/garmin/activity_completion.ts:332–336`, writes the measured start —
   that is the G6/sync rung, unchanged); `final_surge_transformer.dart:363` (`ActualTime` is a
   duration field, unrelated). Do not touch either for Q-D7.
5. **Mirror + ledger:** `docs/ssot/SSOT_SOURCE.txt` pins `@v2` / `cf69821` → re-pin to `@v3` /
   `180658d`. `docs/features/macro_dashboard/README.md` L156–169 records "implemented AHEAD of the
   fold … do NOT land-bundle before the fold" — update: the fold landed, `@v3` is tagged, `@v2`
   will not land (RED by design), `land-bundle` targets `@v3`.
6. **Goldens untouched** (`test/features/macro_dashboard/goldens/workout_card_*.png` ×4 +
   `energy_card_*` ×6): no visual contract changed in v3; regenerate nothing.

---

# Handoff — daily-macros-dashboard@v2 → the coding agent (carried verbatim; still binding under v3)

**Checkout `daily-macros-dashboard@v2`** (commit `cf69821`) in the qa repo (resolve via `$QA_ROOT`
from `mealvana_endurance/workspace.env`). The manifest `bundles/daily-macros-dashboard.yaml` is the
index: 13 slices, 7 named exclusions, done_when. Companion documents: the 168 vectors under
`vectors/daily-macros/`, the two design manifests under `conformance/design/` (v2: 10 goldens,
17 gesture tests), the feature test plan `docs/feature-test-plans/macro-dashboard.md`, and the
2026-08-17 reconciliation of the prototype against this contract,
`docs/design-reconciliation/macro-dashboard-2026-08-17-skip-revision.md`.

**v2 supersedes `@v1` (`e2c3fe0`).** If you implemented against `@v1`, everything below the
"What v2 changes" heading is your delta; the engine vectors are unchanged except the regenerated
`energy-availability.json` `override-ceiling-branch` (expect 168/168, not 167/168). Re-sync
`$APP_ROOT/docs/ssot` as a verbatim mirror of `cf69821` and re-pin `SSOT_SOURCE.txt`.

**The visual design** is `$WORKSPACE/prototypes/macro-dashboard/index.html` @ **`5a22ca8`**
(2026-08-17; the prototypes repo). It is the **reference rendering**; `spec/design/` is the
contract — where they disagree, spec/design wins; where both are silent, ask. Known
reference-rendering defects you must NOT port: W-6 (reveal never auto-dismisses) and **W-10**
(on the previous-day view a second right-swipe lands on a PLANNED card — the app derives past-day
unresolved as SKIPPED). The prototype's day nav (16 ↔ 17) exists to show the SKIPPED state; it is
not itself a contracted surface.

## Port rules (static fidelity)

This is a port, not a redesign. The HTML design above is the visual spec — use its exact values
(colors, fonts, spacing, corner radii), not approximations.

1. Preserve visual hierarchy exactly: which button is filled vs. outlined, primary CTA color,
   text alignment, and element order.
2. Do not substitute, remove, or "improve" any content.
3. If real app data conflicts with static content in the design, ask before changing anything.

Verification loop — for every screen: implement → screenshot in the simulator → side-by-side
against the HTML listing every discrepancy → fix and re-capture until the list is empty → show
the final side-by-side before the next screen. If any decision isn't clearly answered by the
design, ask instead of guessing.

## Design-SSOT rules (behavior + meaning — what screenshots can't hold)

4. Implement every state and gesture contract in `spec/design/components/` — including
   suppressions (G3: a verified card responds to NO swipe in either direction; that row needs a
   NEGATIVE test asserting no reveal, no "Mark undone", no "Skip"/"Unskip" node).
5. Colors follow token MEANINGS (`spec/design/tokens.md`), never just values. In v2 the workout
   card carries **no `dragonfruit` element** — Skip is neutral (dimmed `cream`), not destructive.
6. Numbers come from the engine per the traceability tables (`intraday-display.md` §§1–3) —
   never hard-coded from the mock.
7. Build the goldens (10) and gesture tests (17) per the v2 manifests. A golden may only be
   regenerated after the design spec changed — never to make a red test pass. **`workout_card_
   skipped.png` regenerates now** (spec changed: Q-D5 + Q-D6/D-2) from the reference rendering's
   day-16 run — planned treatment drained to neutral, `Skipped` chip; the commit message cites
   Q-D5 + Q-D6. All other v1 blessings stand.
3a. Alongside the side-by-side, run the component specs' state/gesture checklists.

## What v2 changes on the card (workout-card.md v2, surface v2 — the delta from @v1)

- **Skip replaces delete.** Left swipe reveals a labeled `Skip` (PLANNED / DONE_CONFIRMED) or
  `Unskip` (actively-skipped SKIPPED). No delete affordance renders on the dashboard card. Skip
  only on button press, never by the swipe. Past-day *passive* SKIPPED reveals no button — recovery
  there is right-swipe only.
- **SKIPPED has two triggers.** Passive: day past ∧ `actual_time` null ∧ status ≠ skipped
  (derived — never written; the current day never shows a passive SKIPPED). Active: Skip press,
  **allowed on the current day**, writes `status = 'skipped'` (and clears `actual_time` if the
  card was DONE_CONFIRMED). One golden serves both — the card is identical.
- **Skip scope (S-2):** kcal, fuel windows and timeline entry leave EVERY surface figure in the
  same frame; Unskip / mark-done / sync bring them back. **Tuck (S-7):** a skipped card renders
  with no timestamp after every timed card of its day, rail ink neutral; unskip restores
  `planned_time` and the time-ordered slot. Both Skip and Unskip offer undo (toast).
- **Sync beats skip (G6):** a platform activity matching a skipped row (match key: platform id,
  else platform+sport+start ±15 min) upgrades it to DONE_VERIFIED, `actual_time` = measured start,
  status cleared. The matcher must NOT filter `status='skipped'` rows before matching.
- **G2 lands on the day's derived unresolved state:** PLANNED on the current day, SKIPPED on a
  past day (never a PLANNED card on a past day).
- **Remove** the provisional `skippedPrompt` state ("Did this happen? Swipe right to mark done" +
  same-day-22:00 trigger) — rejected by Q-D5.

## Engine rules

- The vectors are the contract. **Never edit a spec or a vector to make code pass** — red means
  the code is wrong, or a ruling is needed (raise it via `intake/`).
- Expected-red inventory: the four legacy `calculate-daily-macros` test files pin the SUPERSEDED
  engine; they move to the vectors, never the reverse. `energy-availability.json`
  `override-ceiling-branch` regenerated 2026-08-17 (inputs session 2770 → carb 900 / prot 115 /
  fat 70 / adjusted true / carbAtCeiling true / post-override EA 30.0).
- Runner: the Deno harness feeding `vectors/daily-macros/*.json` (unrounded chain, abs tol per
  file; display rounds half-up).
- **Q-016:** any MANUAL write to an engine input invalidates today + all future cached days
  (never past) and refreshes the controller. **Q-017:** no compensation for the cycling no-op;
  the 10b exemption is NOT in this bundle.
- **Schema tasks:** `planned_time` / `actual_time` / `status` — landed in migration
  `20260814120000_activities_two_time_and_tombstone.sql`; **`'skipped'` already exists in
  `activity_status_enum` and in `ActivityStatus`** (verified 2026-08-17) — no enum migration for
  v2, only the write/read paths. `public.plan_recalc_log` written by every recalculateAfterSync.

## Done

All 9 vector files green against the real engine (168/168); every artifact in both v2 design
manifests exists and passes in CI — including g4/g5/g6 and the regenerated `workout_card_skipped`
golden; the schema tasks landed; the delete affordance is gone from the dashboard card; the
feature test plan's rows flip to ✅.

## Known terrain & conflict watchlist (verified against `$APP_ROOT` 2026-08-17)

**This is an UPDATE of a build that already implements @v1**, not greenfield. Verified present:
`lib/features/macro_dashboard/presentation/widgets/workout_card.dart` (delete reveal, L18/L229),
`.../screens/macro_dashboard_screen.dart` (`_deleteWithUndo`, L392–444),
`.../application/dashboard_assembler.dart` (`WorkoutCardState.skippedPrompt`, L104–117; §4b
tombstone filter L48–51), `test/features/macro_dashboard/macro_dashboard_gestures_test.dart`
(g1–g5, g7, e1, p1, s6, sync-upgrade, tombstone, two-time tests), `..._goldens_test.dart` with
four blessed `workout_card_*.png`. Modify in place.

1. **Superseded UI + tests to replace deliberately, not let rot red:** the delete reveal and
   `onDelete` in `workout_card.dart`; `_deleteWithUndo` on the dashboard screen; the
   `skippedPrompt` state + its copy in `dashboard_assembler.dart`; gestures tests
   `g4: partial left-swipe reveals labeled Delete` and `g5: deletion removes...`; the
   `tombstone: a status=deleted row never renders` test stays (the §4b render rule is still
   ratified) but the manifest's `tombstone_prevents_reimport` is retired; `workout_card_skipped.png`
   regenerates (spec change cited).
2. **`ActivityStatus.skipped` has prior meaning.** It is read today by
   `training_insight_service.dart:78` (excludes skipped from insight input — compatible) and
   written from TrainingPeaks imports via `activity_mapper.dart:603` (`'skipped'` → skipped) while
   `vdot_transformer.dart:147` drops TP-'skipped' entirely. A TP-imported skipped row will now
   render as an actively-skipped card (Unskip available). Decide deliberately whether a
   platform-declared skip is un-skippable by the athlete; default = treat as active skip (the
   ruling says the athlete is the tiebreaker) — raise via `intake/` if product disagrees.
3. **Sync matcher path for skipped rows.** `change_detection_service.dart` L133 handles the
   tombstone branch; a matched local row with `status = skipped` falls into the generic update
   branch — verify that branch sets `status` from the platform (completed) and writes
   `actual_time` (G6), and that no earlier filter drops skipped rows before matching (the
   platform-resolution addition forbids it). `activities_repository.dart:97` pulls tombstones
   with `.or('deleted_at.is.null,status.eq.deleted')` — skipped rows have `deleted_at` null so
   they come down already.
4. **Delete elsewhere is untouched.** `calendar_service.dart:56/102`,
   `calendar_controller.dart:215`, coach-mode `coach_activity_detail_controller.dart:187` and
   `portal_athlete_detail_panel.dart:815` keep their delete paths (tombstone semantics per @v1
   watchlist item 5). Only the dashboard card loses the affordance.
5. **Two "deleted" mechanisms coexist:** `deletedAt` / `providerDeletedAt` (provider-side) vs
   `status = 'deleted'` (athlete tombstone). Skip touches neither — do not conflate a skipped row
   with either deletion.
6. **Cross-language parity, deploy coupling, overnight number shift, unspecified legacy
   behavior, old `daily_total_card_*` goldens** — all @v1 watchlist items still stand; the engine
   contract is unchanged in v2 except the erratum vector.
