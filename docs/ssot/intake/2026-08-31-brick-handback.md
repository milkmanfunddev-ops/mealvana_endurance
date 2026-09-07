type: handback
ruling: spec/domain/brick.md v1 (Xuan, 2026-08-31) — intake 2026-08-26-brick-eligibility-logic-ssot.md

# APP-SIDE HANDBACK — brick eligibility ruling (2026-08-31)

Resolve `$APP_ROOT` via `mealvana_endurance/workspace.env` / `find_workspace`. Execute verbatim;
each box cites the rule that gates it.

- [ ] Re-sync `$APP_ROOT/docs/ssot` as a **verbatim mirror** of the qa commit this file lands in
      (includes the NEW `spec/domain/` family); update `SSOT_SOURCE.txt`'s commit pin.
- [ ] **R8 — positional transition identity (fixes D-008).** `generate-macros-v4/brick-workout.ts`:
      emit `transition_name: "T{i+1}"` positionally in BOTH emit sites (the hydration result and
      the phase assembly); carry the sport pair as a separate label field (e.g.
      `sport_pair: "cycling→running"`) for display. `generate-nutrition-plan-v3` already keys
      positionally — after the producer change, delete nothing there, but add the
      **producer-shaped seam test** (qa rule `8b12b9d`): assert the macros payload's transition
      keys equal the plan function's lookup keys for 2-leg bike→run, 3-leg swim→bike→run, and a
      repeat-leg brick (bike→run→bike). Edge-function work goes through the deploy playbook.
- [ ] **R5 — forbid SKIPPED legs (fixes D-007).** `lib/features/activities/domain/brick_eligibility.dart`:
      a `status = skipped` workout is not eligible; add the negative unit test. Leave
      DONE/verified/past/future behaviour untouched (Q-BR1 open — characterization).
- [ ] **R4 — max-3 cap stands.** No change; remove any TODO suggesting the cap is undecided and
      cite `spec/domain/brick.md` R4.
- [ ] **R1/R2/R6/R7 — already implemented** (Lee 2026-08-26, now ratified): update the citations
      in `brick_eligibility.dart`, `brick_selection_controller.dart`, and the class doc on
      `macro_dashboard_screen.dart` to point at `docs/ssot/spec/domain/brick.md` instead of the
      qa intake file.
- [ ] Re-run the conformance suites (deno vectors runner + Dart qa_conformance / parity /
      design suites) and report the counts; the domain slice has no vectors yet
      (`spec-to-vectors` runs after this handback), so no new green expected there.
- [ ] **Explicitly NOT gated here:** the run→bike hydration double-count and the ×0.8-per-pair
      penalty question (both live in the transition-nutrition SSOT session on
      `qa/brick-transition-nutrition`), and Q-BR1/Q-BR2.
