# Deferred ledger — pre-workout-macros (post-@v2, toward implementation)

**What this file is:** the written record of gaps we KNOW about and are consciously shipping
around — so "good enough, move on" never silently becomes "forgotten." One line per item, with
where its full record lives, the **interim default the coding agent implements**, and what
un-defers it. Items leave this file only by being fixed, ruled, or explicitly re-deferred.

**Ship decision (Xuan, 2026-08-26):** no further ruling round this iteration — correct the design
in the app first. Every open question below ships with an interim default; the default is a
*choice recorded here*, not ratified intent, and the next iteration's ruling desk collects them.

| # | Deferred item | Record | Interim default (coding agent) | Un-deferred by |
|---|---|---|---|---|
| P1 | **Hydration check on a GATED plan** (fluid `null`, `t ≥ 120`): render? what does DARK add to? | `intake/2026-08-26-before-card-unowned-links.md` Q1; test plan I5 | **Suppress the check when `regime == "gated"`** (a target that is not stated cannot be raised; F-1 keeps "no target" ≠ "0"). Pin with a negative test named `h_suppressed_when_gated` | Xuan's ruling → hydration-check spec addition |
| P2 | **Persistence** of the answer, stepper edits, added water row; client-only vs server recompute | same file Q2; test plan I10; §6.4 | **Persist all three in `activities.nutrition_plan_data` beside the plan; recompute client-side via `OfflineMacroCalculator` (the authority per the app file header); one atomic write.** No new edge-function request field this iteration | ruling → a "Persistence" contract on the surface spec + schema task |
| P3 | **Row removal** + fate of an edited tagged water row on Change answer | same file Q3 | **Stepper to 0 removes any row; the tag governs — an edited tagged row is still removed on revert (H-4 literal).** No swipe-to-delete | ruling → feeding-card FC-G2/FC-7 |
| P4 | **MEAL title:** FC-1 "Pre-Run Meal always" vs the app's sport-varying titles | same file Q4; §6.1 | **Implement FC-1 as ratified ("Pre-Run Meal" for every sport)** — the spec is the contract; the app's `pre_workout_feeding_labels.dart` sport variant is retired for the BEFORE card | ruling (erratum on FC-1 if run-only was unintended) |
| P5 | **notes §6 stale lines** (5 g carb rounding vs M-5 whole gram; clock-gated check; cue in every tier; `renderAs`) + R-01 oz rule not yet folded | `intake/2026-08-26-pre-workout-notes-s6-stale-after-pw021-and-m5.md`; test plan I11 | **The newer ratified documents win: fuel-stat M-5 (whole gram), R-01 (oz: target `round(ml/29.5735)`, band `[floor, ceil]`), PW-021.** notes §6 is NOT edited this iteration | erratum fold (apply-ruling) |
| P6 | Carbs at `t = 0`: band `[0,0]` suppressed — is 1 g delivered an "above ceiling" alarm? | same erratum file, adjacent question | **No alarm when the band is suppressed** (no rail ⇒ no out-of-band state) | ruling → fuel-stat M-2 note |
| P7 | **PW-003 fluid-gate thresholds** (29 % of prod plans gated) | `intake/2026-08-25-pre-workout-fluid-gate-thresholds.md` | gate unchanged (v6 as ratified); the card renders the gate honestly (F-1) | Xuan's ruling |
| P8 | **QA-repo conformance harnesses** (`qa/conformance/pre_workout_*_conformance_test.dart`) broken/stale; `run_dart.sh` red for all three slices | `intake/2026-08-25-hydration-slice-stale-v1.md`; test plan §6.2 | The app's `test/qa_conformance/*` (74/74, CI) are the gate of record for the math slices; QA copies to be replaced verbatim from the app at handback (I4) | handback item; land-bundle gate must run the app copies |
| P9 | **Fine print `?`** suppressed (S-G4) — below 2 h the surface carries no hydration cue at all | surface S-G4, B-4 | control ABSENT (not inert); pin `s_fine_print_absent` | the fine-print / explanation SSOT |
| P10 | **Food-composition v3 has no engine/runner** (`engine: null`, 87 vectors) | `bundles/pre-workout-food-composition.yaml` | out of this bundle; "+ Add Food" offers the existing catalog; gates not enforced | that bundle's implementation |
| P11 | **D-001 fasted → zero** unratified; **D-016 480-min stepper** (PW-011) | `DEVIATIONS.md` | fasted rendered per FC-4 (characterization); stepper cap 240 + clamp on load is a code fix in scope of the handoff | rulings / fix |
| P12 | `qa/pre-workout-drawers` branch unmerged (math v6 history; files imported here file-level) | memory + branch | none needed for this bundle (contents identical) | a deliberate land-bundle-style merge |
