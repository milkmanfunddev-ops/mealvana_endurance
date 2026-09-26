type: handback
bundle: data-integrations@v1 (pre-ship) + daily-macros-dashboard (rulings 2026-09-10)

# APP-SIDE HANDBACK — data-integrations ratification (ruling desk 2026-09-10)

Authority: Xuan's RULING-DESK 2026-09-10 fast-track block (applied on `qa/data-integrations`,
commit cited in the batch commit message). The `spec/integrations/` family is RATIFIED; the
contracts below are the implementation surface. Resolve `$APP_ROOT` via
`mealvana_endurance/workspace.env` / `find_workspace` — never hardcode. Sequencing: after
brick-transition ships; `spec-to-vectors` will land `vectors/integrations/` before
implementation is gated green.

## 0 · Standard items
- [ ] **Follow the staged rollout order in
      `docs/feature-test-plans/data-integrations.md` §3** — five stages, each green-gated;
      Stage B's harness runs the 39 matching vectors RED against current code BEFORE the
      rewrite lands (a harness born green proves nothing). Migration rehearsal protocol
      (§4 there) is mandatory before the enum/dead-column migrations touch dev.
- [ ] Re-sync `$APP_ROOT/docs/ssot` as a **verbatim mirror** of the qa batch commit; update
      `SSOT_SOURCE.txt` pin.
- [ ] Re-run conformance suites (deno vectors runner + Dart intraday/parity/design) and
      report the green count before/after.
- [ ] Flip matching rows in `docs/feature-test-plans/*.md` only when a pinned test exists.

## 1 · Capture contract (Q-INT26 maximal + shortlist order; per-source columns, planned/actual split)
- [ ] Every DISCARDED/UNHANDLED field in `spec/integrations/payload-usage-map.md` gains a
      per-source typed column (L-2 convention); sole exception: Garmin per-sample streams
      (dated decision 2026-09-09). Implement in shortlist order (§6):
      1. TP `TssActual`+`IF` → `tss_actual`, `if_actual`
      2. TP `TSSPlanned`/`IFPlanned` → `tss_planned`, `if_planned`
      3. `parentSummaryId`+`isParent` persisted (column or brick_metadata)
      4. TP Metric fetch (weight, HRV) on the 24 h zones clock (premium-gated)
      5. Zones → consumption: `_classifyIntensity` uses athlete zones; FTP prefill to
         `users.cycling_ftp_watts` (Q-INT19)
      6. FS/TP `workout_subtype` + FS pace min/max onto the row (Q-INT13)
      7. TP `IsPremium` → `integrations`
      8. ALL unhandled Garmin push types handled into `garmin_health_data`
         (hrv, pulseOx, respiration, healthSnapshot, bloodPressures, skinTemp)
      9. TP `Calories` + `CaloriesPlanned` record-only columns (F4 stays authoritative)
      10. FS `WorkoutRace` / TP `Goals[]` → race flags + event-page prefill; TP races via
          events API (confirm `/events/next` horizon); FS long-horizon race-only scan
          (daily, ≤12 mo, chunked — the 14-day cap is our clamp; probe FS server limits
          once); events may move to a daily clock.
- [ ] **Planned/actual split (L-2)**: completion stops double-writing measured values into
      planner columns; `duration_minutes`/`distance_*`/pace targets stay planned;
      measured → `actual_*` only; consumers read `actual ?? planned`.
- [ ] CTL/ATL: no provider sends them — engine slots stay; compute in-house from captured
      TSS when the feed exists (Q-INT17). No extractor to build now.

## 2 · Matching contract (matching.md M-0..M-5, RULED)
- [ ] **M-1.2 trigger contract**: platform-keyed completion by plan ID, no threshold;
      Garmin completion via guard + best-fit (closest planned slot to measured start, then
      duration fit; ties → earliest slot; NO manual-resolution UI); late platform signal
      verifies or reverts-and-rebinds (displaced activity re-scores).
- [ ] **Q-INT21 guard**: refuse when measured < 20% of planned or < 2 min; refusal falls
      to auto-insert. Applies to planned, skipped, and upgrade tiers.
- [ ] **Q-INT24 upgrade**: completed rows lacking `garmin_summary_id` (mark-done OR
      hand-created) are upgrade targets — same sport + same local day, closest start wins
      (day-wide deliberately: mark-done actual_time inherits the planned slot). Guard applies.
      NOTE: Q-INT4's text lists "upgrade" under the ±15 key; Q-INT24 (same batch, specific,
      Xuan-steered) governs — day-wide.
- [ ] **Q-INT22 brick verification**: B-1..B-5 with B-2′ sequential legs primary
      (sports in start order = segment order, inter-leg gap ≤ 30 min, guard per leg);
      parent stamped; verified = ALL endurance legs matched; transitions folded into
      brick_metadata (all TRANSITION_* variants mapped → never standalone rows);
      no parent/child double import (B-5). Needs `parentSummaryId` persistence (item 1.3).
- [ ] **M-0/M-1.1 companions**: one-row invariant; Garmin-signal sufficiency; measured
      start+duration signature tiebreaker (~1-2 min / few %); timezone-defensive instant
      comparison INSIDE the matcher (storage stays naive-local per L-9.2).
- [ ] Cross-provider planned completion stays by design; `other` refusal kept (revisit
      post-guard).

## 3 · Disconnect redesign (Q-INT2) + custody
- [ ] Default disconnect = **soft-hide**: hidden-by-disconnect flag (NEW state, distinct
      from `status='deleted'`) on provider rows AND `garmin_health_data`; tokens cleared;
      F27 rerun. Reconnect revives via provider id / summary id (hidden rows
      match-and-revive, never suppress). Explicit "also delete my synced data" choice =
      hard purge incl. wellness + `users` mirrors. Replaces the hard-purge path.
- [ ] **Q-INT8 tokens**: `integrations` sole store; strip token copies from
      `garmin_user_mappings`; delete the stale auth `user_metadata` store (dead
      `sync-final-surge` removed); verify RLS on token tables via `pg_policies`.
- [ ] **Q-INT16 write-back**: default OFF (fix `?? true`); create the server-side
      write-back ledger — REQUIRED before any push; disconnect strips Mealvana blocks
      best-effort + purges ledger; verify the full-object PUT end-to-end before re-enable.
      **CONFIRMED FIRED in prod (2026-09-10: coach screenshot of a client's TP
      description with the [Mealvana Fuel Plan] block — and the coach loves it).**
      **AMENDED (Xuan, 2026-09-10 evening — implement):** (a) prominent opt-in consent
      prompt at TP connect ("share your fuel plan to your TP calendar so your coach sees
      it"); keep the Connected Apps settings toggle (exists — flip only the ?? true
      default); per-push success/failure rows in the ledger (mirror the existing local
      Drift tp_writeback_log to the server-side ledger). Migration prompt for
      already-pushing athletes remains STAGED pending Xuan's word.
      **RULED rendering (Xuan, 2026-09-10 — option A, single block):** the
      [Mealvana Fuel Plan] block is Pre/During/Post at plan time, and at fuel-log time
      the SAME block is REPLACED in-place with the combined form, each phase line
      planned · consumed (e.g. "Pre: 80g carb planned · 60g consumed"). One block for
      the fuel story; [Mealvana Feedback] (rating/notes) remains separate. **Macro register RULED (Xuan, 2026-09-10): Pre + During ONLY — remove the
      Post line** (formatter currently emits one). Pre = carbs g, water oz, timing.
      During = carbs g/h (essential), water oz/h, sodium mg/h (ADD — absent today).
      Consumed counterparts from fuel_log_data at log time. Build AFTER the sandbox
      probe confirms TP accepts the plan-PUT post-completion (the shipped Feedback
      path implies it does).
      **IMPLEMENTED 2026-09-14 (ships in 1.27.0; app commits feat 821c1385 + fix
      4f0ad533): `formatLoggedPlanBlock` re-renders the [Mealvana Fuel Plan] block
      as planned · consumed and replaces it in-place at fuel-log completion. Pre =
      absolute planned · consumed per field; During = per-hour rates on carb/water/
      sodium (RULED Xuan 2026-09-14). The build gate (post-completion plan-PUT) is
      cleared by the shipped Feedback path AND the 1.27.0 prod writeback smoke. That
      same prod smoke caught a lost-update race — the completion feedback push and
      the logged-plan re-push were concurrent GET→PUT on the one Description field;
      fixed by sequencing them (feedback block preserved via the `(?! Feedback)`
      strip lookahead). Verified live on Lee's production TP.**
      Delimiter robustness fix: the fuel terminator [/Mealvana] is a PREFIX of
      [/Mealvana Feedback] — a truncated fuel block would make the strip regex swallow
      the feedback block (athlete notes included). Fix: negative lookahead
      \[/Mealvana\](?! Feedback) or a non-prefix end tag.

## 4 · Engine rulings (daily-macros)
- [ ] **Day-bucketing** (intake 2026-08-20, opt 1): engine buckets by
      `actual_time ?? planned_time ?? scheduled_date_time` — audit all four
      `daily_macro_service` day/context/weekly queries + TS twins.
- [ ] **F4a** (session-demand fold): MOBILITY 2.5 linear; composites decompose; unknown →
      0 + estimate flag; remove `?? 11` in Dart + TS twins. Vectors: added by qa via
      spec-to-vectors (do not hand-write).
- [ ] **STAGED (class c — do NOT implement yet)**: Garmin kcal BMR correction
      (F22: `calories_burned − RMR/24 × dur`, raw verbatim) ships with
      platform-resolution's next version via ship-bundle.

## 5 · Hygiene batch (Q-INT25) + small fixes
- [ ] Enum-casing migration (archivedForBrick/archived_for_brick → one), live brick
      migration (out of `_archived/`), decide/align `draft` + `transition` enum values,
      remove dead columns (`activities.tss` after tss_planned/actual land,
      `integrations.threshold_pace_min_per_mile`, `users.prefers_*`, activity FTP/CSS/
      speed orphans), unify the three session fingerprints.
- [ ] Q-INT10: widen server CHECK to include `requires_reauth`.
- [ ] Q-INT14: TP host env-driven; release builds default production.
- [ ] Q-INT9: security findings (webhook auth, SSRF, committed secrets) tracked ops-side.

## 5b · Design slice (re-scoped per Xuan's rule: provenance map + Claude Design handover)
- [ ] BLOCKED on the Claude Design handover for P1/P2/P3 (prompts live on the review
      artifact 7161f58f); after handover, QA ratifies every number on the new designs,
      THEN goldens/gestures manifests. The D-contracts below are the prompts' constraints.
- [ ] D-1 card numbers: verified shows measured (actual_*), planned/confirmed/skipped show
      planned; never mixed pairs. Await Q-DID1 (delta subtext) before goldens.
- [ ] D-2 FTP/CSS provenance chips + TP prefill + conflict notice. Await Q-DID2.
- [ ] D-3 consent prompt (connect + onboarding step), settings toggle w/ last-push from
      the ledger, premium-blocked state with Re-check. Await Q-DID3 (copy + migration moment).
- [ ] Conformance: goldens/gestures manifests per the house pattern once Q-DID1..3 rule.

## 6 · Garmin-only athletes (Q-INT18)
- [ ] Activities backfill at connect (chained ≤30-day windows; fix the 90-day clamp);
      TrainingInsightService insights; synthesized forward template (provenance-tagged
      "generated", athlete-confirmed).
- [ ] **Xuan's addendum**: the insight engine EXISTS (`TrainingInsightService`,
      onboarding digest — heavy/light weekdays, reliability gates). Queue a live test:
      run it over a Garmin-backfilled month (e.g. Xuan's account on dev) and review its
      output before the template feature builds on it.

## 7 · One-time probes (Xuan runs / assists)
- [ ] FS completed-workout probe (Xuan's FS connection): does FS populate
      ActualTime/ActualDistanceMeters, and do timestamps carry an offset? Keep the raw
      payload.
- [ ] TP `/events/next` horizon check; FS `Workouts` date-range server cap probe.

## Deferred this round (no action): Q-INT1 retention, Q-INT3 provider-side revocation,
Q-INT5 provider_deleted_at semantics, Q-INT6 platform-declared skip (+ its intake, left
unstamped), Q-INT7 orphaned null-user rows, Q-INT15 sport-map ratification.

## Addendum — Q-INT27 first-connect window contract (RULED Xuan, 2026-09-11)
Supersedes the window details above where they differ:
- [ ] **FS forward window → 28 days** (today's 14 is our clamp). GATE: run the §7 FS
      date-range server-cap probe first, plus one live check of the 404-fallback path
      (`UpcomingWorkouts` at `NumDays` > 14) — ship the widened window only after both.
- [ ] **Garmin connect-time backfill adds `activities`, 30 days** — ONE window at
      Garmin's per-request max; §6's "chained ≤30-day windows" is fixed at one window
      (chaining stays a future option pending the insight-engine live test). The 90-day
      clamp fix in §6 still applies.
- [ ] **No TP/FS history import** — dated decision (Q-INT27); do not wire the range
      endpoints backward. Revisit only with a load-context feature.

## Addendum 2 — Q-INT16 consent posture AMENDED to opt-out (RULED Xuan, 2026-09-11)
Supersedes the write-back consent items above:
- [ ] Write-back **defaults ON for everyone** — today's `?? true` becomes the ratified
      intent (make it an explicit pref default, not a null-fallback). Do NOT ship the
      opt-in flip.
- [ ] Connect-time sheet becomes an opt-out NOTICE (still fires after every successful
      TP connect; toggle pre-set ON; dismiss = stays ON). Copy/actions arrive from the
      next Claude Design iteration — do not build the sheet until QA hands the ratified
      export.
- [ ] Migration: existing TP athletes get the same notice ONCE on first launch
      (notice-once semantics; DI-10 gains a notice-once test). No one's push flow stops.
- [ ] Unchanged: server ledger required before any push; premium latch + Re-check;
      disconnect strips blocks and purges the ledger; in-row toggle is the opt-out.

## Addendum 3 — design-slice close-out (RULED Xuan, 2026-09-11)
`integrations-data-display.md` is now RATIFIED. Implementation items it gates:
- [ ] **Brick border fix (D-1b):** brick card at creation must render the DASHED outline
      like every planned card; solid only on self-reported/verified completion (today it
      is solid from creation — divergence from the ratified design).
- [ ] **Body Composition source chips (D-2b):** Manual·Garmin chip under weight and
      body-fat; stale chip past 30 days; newest-wins precedence preserved as built;
      tap-to-use chip for the older-Garmin/newer-manual case. Reuse the ratified P2 chip
      components.
- [ ] **Events origin chip (D-2c):** origin chip per event row (Manual·TrainingPeaks·
      Final Surge); dedupe-match flips origin to provider; local edit of a provider
      field flips it manual and exempts it from re-sync overwrite (new contract line —
      needs a small behavioral test).
- [ ] Goldens/gestures manifests for D-1..D-3 surfaces per the house pattern (DI-15),
      incl. the consent-sheet opt-out visibility assertion.
