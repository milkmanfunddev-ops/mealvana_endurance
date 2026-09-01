# QA expansion plan

Scales the proven pilot (pre-workout carbs, `ops/docs/qa-department-plan.md`) across all
calculation engines. Structured around Xuan's step 1: **he hands over SSOT slices; we record,
stamp/ratify, vector, and conformance-test them — slice by slice.**

Governing rule (already law here): **implementation is not authorization.** Code behavior the
SSOT never ratified → a documented deviation, never a silent spec edit. Every slice will
surface its own deviations to rule on (as fasted did).

---

## Phase 0 — DONE
Pilot: pre-workout carbs. Pure-Dart `OfflineMacroCalculator`, 6 ratified vectors + 1
characterization (fasted), green. The loop is proven.

## Phase 1 — SSOT-slice conformance sweep  ← START HERE (cheap, exhaustive, no Lee dependency)

The pilot loop, repeated per slice. **Per slice:**
1. **You hand me the SSOT** (the drawer/doc for that section).
2. **Record** it → `qa/spec/<engine>/<section>.md` (+ `.html` source), stamped with a date.
3. **Ratify** — I derive the rules from your SSOT + the code; you rule on any deviations
   (accept → SSOT, or log → `DEVIATIONS.md`).
4. **Vector** — I generate cases from (a) the SSOT worked examples, (b) every code branch,
   (c) boundary values. Vector *supply* is unlimited (generated to order); your SSOT + rulings
   are the only budget.
5. **Conformance** — extend the runner to assert the real code; run green.
6. **Log deviations + commit.**

**Slices to cover** (each its own spec + vectors):
- **Fueling engine A** (pure `OfflineMacroCalculator`, per-workout): pre / during / post ×
  carbs · protein · fat · sodium · hydration. During-carbs alone (duration bands × gut
  multipliers × sport ceilings) will yield 20–40 vectors.
  **Pre-workout: steps 2–3 DONE 2026-08-03** — carbs v2, hydration v6 and sodium v3 all RATIFIED
  (`spec/fueling/pre-workout-{carbs,hydration,sodium}.md`, reasoning in `pre-workout.notes.md`).
  Step 4 (vector) is the next action; all v1 vectors are obsolete because the output shape changed.
  Everything deferred or still owed is indexed in
  **`spec/fueling/pre-workout.OPEN-QUESTIONS.md`** — 18 rows, of which **PW-011 / PW-012 / PW-013
  are app changes the vectors must assert against**, so they gate step 5, not step 4.
- **Recommendation scaling core** (pure `FormulaMacros.carbScaleFactor` / `scaledQuantity`,
  `formula_kit/domain/formula_macros.dart`): scale a kit's components to a carb target,
  snapped to 0.5-serving steps. Exactly vectorable; already has `formula_macros_test.dart` to
  build on. Also vector the rounding hotspots (`roundFriendlyQuantity`'s 0.08 tie-break,
  `_snapToFriendly`).
- **Daily-macro engine B** (server-only `calculate-daily-macros`, no Dart mirror): vectors run
  against the edge function, not Dart. Later in the sweep (needs a callable test endpoint).
  **Step 2 (record) DONE 2026-07-28** — `spec/daily-macros/` (9 sections, iterations 1–5 of the
  Notion "Daily Macro Calculation" doc; iteration 6 / proration deliberately excluded). Step 3
  (ratify) is blocked on `spec/daily-macros/OPEN-QUESTIONS.md` — 12 SSOT-internal contradictions,
  5 of which must be ruled on before vectoring.

**Dart↔server contract:** the Dart calc + scaling both *mirror* Supabase edge functions
(`generate-macros-v4`, `personal-formula-pins`). The same vector table should run against
**both** implementations to guard the "keep in sync" claim — that's where prod-vs-offline
drift hides.

## Phase 2 — Test-athlete provisioning (prereq for the sim layer; I prep, you run)

**Reality (from recon):** no turnkey mechanism exists. Fixtures are in-memory only (no login);
the coach portal only *edits* existing athletes; the branch doc is a provider routing table,
not the app schema. The app's real profile schema is in code (`user_profiles.dart`, Supabase
table `users`) — note **weight is stored in pounds, height in feet+inches**; the engine
converts lb→kg (`× 0.453592`).

**The path:** a NEW seed script that provisions 20 athletes in **dev** Supabase (`signUp`, or
`auth.admin.createUser` with service_role) + writes each profile row from the schema.
- **I author:** the 20 **persona definitions** (`qa/profiles/athletes.json`) + the seed script.
- **You / Lee run** the provisioning — account creation and any service-role secret are yours,
  not mine (I set up the tooling; I don't create accounts or handle credentials).
- **Personas chosen for BOUNDARY coverage**, not just variety: light + heavy (post-workout
  protein `min(40,max(20,…))` rails), high-sweat + hot (hydration clamps), short vs long
  duration (carb bands), a fasted case, a swimmer (fasted forced off, carb ceiling 0), diet
  variety (allergen/veg for the recommendation kit). Sampled from, not all run every time.

## Phase 3 — Integration / simulator layer ("one path → compare all macros, all phases")

Xuan's key efficiency insight, kept exactly: navigating to a result is the expensive part, so
each run asserts the **entire** macro set (before/during/after × every macro) at once.

- **Mechanism: Flutter `integration_test`**, driven by widget **keys** (login uses
  `login.email_field` / `login.password_field`; the fasted toggle has
  `activity_create.fasted_toggle`) — NOT MCP coordinate-tapping (that's for ad-hoc capture,
  too brittle for a repeatable suite). It reuses the **same vectors**, logs in programmatically
  (no manual credential entry by me), and asserts on-screen values.
- **Determinism:** pin temp/humidity via the controller setters
  (`updateTemperature` / `updateHumidity`, defaults 20 °C / 60 %) or deny location; fixed
  personas; **seeded** sampling of (athlete × workout) so a failure is reproducible.
- **Expected values are GENERATED from the ratified spec** per (athlete × workout) — never
  hand-punched. The test then verifies **three engines agree: spec ↔ server ↔ screen** (the
  server path is what users actually get; conformance alone only tests the offline mirror).
- **Workout library** (`qa/workouts/*.json`): sport · distance · pace · duration · hoursBefore
  · fasted · temp · humidity · indoor · terrain — environment pinned for reproducibility.
- **Needs from Lee:** widget keys on the fueling-window field + the displayed macro values
  (some exist); the seed script wired to dev Supabase.

## Phase 4 — Invariant harness for the impure orchestrators

`ClientPlanService` (plan assembly) and the macro-generation orchestrator carry `DateTime.now()`,
UUIDs, and repo-ordered food selection → **not** exact-vectorable. Cover with **invariants**:
scaled carbs ≈ target (within 0.5-serving rounding) · fluid total ≥ target · sodium ≤ 110 % of
target · no component < 0.5 serving. Via Riverpod overrides + frozen clock, or covered
end-to-end by the Phase-3 sim layer.

---

## Sequencing

1. **Now:** Phase 1 slice-by-slice as Xuan hands over SSOT docs (start with the fueling
   sections + the recommendation scaling core — both pure, no Lee dependency).
2. **In parallel:** I draft the 20 personas + the seed script (Phase 2), so provisioning is
   ready to run when you want the sim layer.
3. **After** a stable ratified vector base + Lee provides keys/provisioning: Phases 3–4.

## Ownership / constraints
- **I do:** specs, vectors, conformance runners, invariant harnesses, persona definitions,
  seed-script authoring, `integration_test` authoring.
- **You / Lee do:** run the account-provisioning script, hold the service-role secret, add
  widget keys. (I author the tooling; account creation and credential handling stay with you.)
- **Location/env** is fully controllable (setters / deny location) — determinism is solved.
