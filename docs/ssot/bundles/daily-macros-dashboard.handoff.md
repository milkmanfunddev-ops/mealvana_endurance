# Handoff — daily-macros-dashboard@v1 → the coding agent

**Checkout `daily-macros-dashboard@v1`** in the qa repo (resolve via $QA_ROOT from
`mealvana_endurance/workspace.env`). The manifest `bundles/daily-macros-dashboard.yaml` is the
index: 13 slices, 5 named exclusions, done_when. Companion documents: the 168 vectors under
`vectors/daily-macros/`, the two design manifests under `conformance/design/`, the feature test
plan `docs/feature-test-plans/macro-dashboard.md`.

**The visual design** is `$WORKSPACE/prototypes/macro-dashboard/index.html` @ `aa81d21`
(the prototypes repo). It is the **reference rendering**; `spec/design/` is the contract — where
they disagree, spec/design wins; where both are silent, ask.

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
   suppressions (G3: verified cards do not respond to the done gesture; that row needs a
   NEGATIVE test).
5. Colors follow token MEANINGS (`spec/design/tokens.md`), never just values.
6. Numbers come from the engine per the traceability tables (`intraday-display.md` §§1–3) —
   never hard-coded from the mock.
7. Build the goldens (10, per `conformance/design/macro-dashboard.goldens.yaml`, from the
   canonical mock day) and the gesture tests (13, per `...gestures.yaml`). A golden may only be
   regenerated after the design spec changed — never to make a red test pass.
3a. Alongside the side-by-side, run the component specs' state/gesture checklists.

## Engine rules

- The vectors are the contract. **Never edit a spec or a vector to make code pass** — red means
  the code is wrong, or a ruling is needed (raise it).
- Expected-red inventory: the four existing `calculate-daily-macros` test files pin the
  SUPERSEDED engine (uncapped fat, 40 g strength, TP-first tomorrow, F19 rounding). They go red
  against the ruled specs correctly; move them to the vectors, never the reverse.
- Build the runner: a Deno harness feeding `vectors/daily-macros/*.json` to the formulas
  (expected values are the unrounded chain, abs tol per file; display rounds half-up).
- **Schema tasks owned by this bundle** (in no migration today): workout rows gain
  `planned_time`, `actual_time` (nullable), `status` ('deleted' tombstone; match key =
  platform id, fallback platform+sport+start ±15 min); `public.plan_recalc_log` written by
  every recalculateAfterSync.

## Done

All 9 vector files green against the real engine; every artifact in both design manifests exists
and passes in CI; the two schema tasks landed; the feature test plan's rows flip to ✅.

## Known terrain & conflict watchlist (verified 2026-08-14)

**This is an UPDATE, not a greenfield build.** `calculate-daily-macros/formulas/` matches the
specs' conformance targets file-for-file (rmr/baseline/session/multi-day/neat-tef/safety/resolve
.ts all exist). Modify in place; create only: assembly step 10b (fat cap), the two schema tasks,
the intraday-display consumer, and the new dashboard UI + its tests.

1. **Cross-language parity is live and will bite first.** `parity-fixtures.test.ts` runs the SAME
   fixture file as the Flutter side (`test/features/onboarding/fixtures/plan_preview_parity.json`)
   — a Dart twin computes (at least) baseline/preview math. Updating the edge function alone
   breaks parity. Both sides move in lockstep, and the parity fixtures are REGENERATED FROM THE
   VECTORS (never hand-patched to keep parity green on old numbers).
2. **Deploy coupling.** The Flutter app and the edge function deploy separately (the PW-013
   lesson). The response gains `energy_basis` and pins the sources enum / `delta: null` — verify
   old clients tolerate the additions, and sequence client-parsing changes BEFORE engine deploy.
3. **Users will see different numbers overnight.** Fat drops from ~45–50 %E to 30 %E; carbs rise
   correspondingly (run day 369→548 g); strength days drop ~13 g; tomorrow resolution flips to
   manual-wins. Invalidate cached plans on engine version bump (the macro_cache_invalidation
   suite is the place), and flag the shift to product for comms — it is correct, and it is large.
4. **The specs were never diffed against this code** ("name match only"). The code may contain
   behavior no spec mentions. Do not silently delete it: a divergence the vectors don't explain
   gets REPORTED (ruling or DEVIATIONS.md entry), not bulldozed.
5. **Soft-delete touches more than the dashboard.** Existing delete paths (calendar service,
   coach-mode controllers) presumably hard-delete; they must migrate to the tombstone too, or a
   coach-side delete reintroduces the reappearing-workout bug the dashboard just fixed.
6. **The old daily-macros UI and its goldens** (`daily_total_card_*.png`) predate the new design.
   Whether the new dashboard replaces or coexists (feature flag) is a product decision — ask;
   either way the old goldens' fate is decided deliberately, not by letting them rot red.
