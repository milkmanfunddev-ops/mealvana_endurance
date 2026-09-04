# conformance/ — feeding the vectors to the real code

Three arms, one vector set. Each arm copies nothing permanent into a repo (the prototype and Dart arms drop an
ephemeral test file and remove it), resolves paths through `workspace.env` (`APP_ROOT`; `PROTO_ROOT` defaults to
`<workspace>/mealplanning-prototype`), and returns the exit code as the gate.

| Arm | Runner | Engine under test | Covers |
|---|---|---|---|
| edge | `run_edge.sh` → `edge_vectors_test.ts` (Deno, `-A --no-check`) | `$APP_ROOT/supabase/functions/_shared/vana/{derive-week-character,plan-math,opener,season,grocery,meal-icon}.ts` | week-character · plan-coverage · cooking-sessions (+ sessionDates) · opener-selection · season · shopping-list · meal-icon — **109 vectors** |
| prototype | `run_prototype.sh` → `prototype_vectors.test.ts` (vitest, copied into `packages/web/tests/`) | `@/lib/derive-week-character`, `@/lib/vana/meal-icon`, `@/server/vana/{grocery,plan,meals,chat,tools}` | week-character · plan-coverage · cooking-sessions · shopping-list · meal-icon · week-contexts · attribution-short · clamp-sentences — **111 vectors** (2 expected-red D-011, 1 skipped edge-only) |
| dart | `run_dart.sh` → `dart_vectors_test.dart` (flutter test, copied into `$APP_ROOT/test/`) | `PlanCoverageService`, `CookingStepTimers`, `MealIconClassifier` | plan-coverage · cooking-timers · meal-icon — **60 vectors** |

`run_all.sh` runs edge → prototype → dart and stops at the first red.

## Results — 2026-09-03

```
edge       109 passed · 0 failed
prototype  108 passed · 2 failed (EXPECTED-RED, D-011) · 1 skipped
dart        60 passed · 0 failed      (after correcting one hand-counted index in cooking-timers.json)
```

## Rules

- **Never edit a vector to make an arm green.** A red vector is a finding: a twin drift (→ `DEVIATIONS.md`), a
  wrong expectation (→ fix the vector *and* say why in its `why`), or a spec question (→ `OPEN-QUESTIONS.md`).
- **`characterization` vectors are tripwires.** They pin behaviour the record thinks is wrong (the `why` says
  so and names the Q). When the behaviour is fixed the vector flips red — that is the signal to rewrite it as
  `proposed` against the ruled rule.
- **Byte-identity is the cheaper guard for the copied modules.** `derive-week-character.ts`, `meal-icon.ts` and
  `grocery.ts` are meant to be verbatim between prototype and edge; a `diff` (ignoring quote style and the
  import lines) should be empty. The vectors catch semantic drift; the diff catches everything.
- **Dates:** week-character vectors use `dayOffset` because the engine windows on `Date.now()`; never assert
  `anchorDayName`.

## Not yet covered (the honest list)

| Gap | Why | Next step |
|---|---|---|
| athlete-context arithmetic, day-guidance table, batch re-derive, on-hand re-ranking, cooking timers (TS) | logic inside DB-bound or unexported functions | extract pure functions (Q-AC1, Q-DG1, Q-CS2, Q-SG1, D-013), then add vectors |
| `search_meals` invariants MS-1…MS-6 | SQL | a seeded seam test against dev (one athlete: gluten allergy, vegan, one −1 vote, one saved meal) |
| plan lifecycle P-1…P-14, memory MEM-*, conversation C-* | DB state | the edge `contract.test.ts` fixtures + Dart repository tests today; a Deno seam test over the RPCs next |
| the agent contract | model behaviour | `scripts/vana-eval/run.ts` + `lifecycle.ts` (bills spend, by hand) — add `no_body_talk` (Q-AG1) |
| design family | goldens / gestures | the app's meal-planning suites via `scripts/run-meal-planning-tests.sh`; no manifests yet (Q-DS1) |
