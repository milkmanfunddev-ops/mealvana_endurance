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
- **Recommendation scaling core** (pure `FormulaMacros.carbScaleFactor` / `scaledQuantity`,
  `formula_kit/domain/formula_macros.dart`): scale a kit's components to a carb target,
  snapped to 0.5-serving steps. Exactly vectorable; already has `formula_macros_test.dart` to
  build on. Also vector the rounding hotspots (`roundFriendlyQuantity`'s 0.08 tie-break,
  `_snapToFriendly`).
- **Daily-macro engine B** (server-only `calculate-daily-macros`, no Dart mirror): vectors run
  against the edge function, not Dart. Later in the sweep (needs a callable test endpoint).

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

## Phase 5 — The DATA SSOT (producer row shapes) — a ratification family in its own right

**Queued 2026-08-22.** Every family above ratifies *math*: given these inputs, this output. No
family ratifies **what the inputs actually look like in production** — the shapes of the rows
the app itself writes. That hole shipped a bug: providers deliberately write
`activities.duration_minutes = NULL` whenever a workout carries distance or pace (asserted ten
times in `final_surge_transformer_test.dart`, with a documented expectation that consumers
derive the minutes), four consumers each resolved it their own way, and the newest one skipped
the derivation entirely — pricing every distance-prescribed session at a flat 60 minutes, ~47%
low on a 15-mile run, while the macro targets on the same screen used the correct value.
Full analysis: `ops/data/bug-reports/2026-08-22-dashboard-prices-distance-sessions-at-flat-60min.md`.

Vectors are the right instrument, pointed one layer lower. Math vectors say *given inputs →
output*; **shape vectors say: these are the row shapes production actually contains, and this
is the resolution ladder each derived field follows.** Same artifact, same ratification gate,
same two-runtime consumption.

Proposed shape, reusing the existing conventions — no new top-level folders:

- `spec/producers/*.md` — one doc per writer (final-surge, training-peaks, runna, garmin,
  manual create). Normative statement of which fields it writes, which it deliberately leaves
  NULL, and what it expects consumers to do about each.
- `spec/producers/resolution-ladders.md` — for each derived quantity (duration, IF, weight,
  pace), the ONE ordered ladder every consumer must follow. Today's divergences are the first
  content: duration (distance×pace → default 30/60 vs bare `?? 60`), `other`→sport mapping
  (strength@30 vs unmapped@60), zoneless IF (engine 70/20/10 = 0.7715 vs display flat 0.74 —
  already open as `intake/2026-08-20-zoneless-if-default-engine-vs-display.md`).
- `vectors/producers/*.json` — the ratified corpus: real provider payloads → the `Activity`
  rows they produce → the resolved inputs each ladder yields. Ratified through the normal ⚖ gate.

**Where the contract TESTS live:** in `app/`, like every other runner — this repo owns the
contract, not the harness. Registered as a conformance slice in `bundles/<bundle>.yaml` and
dispatched by `conformance/run_dart.sh` exactly as the fueling and design slices are; the app
side mirrors `vectors/producers/` into `docs/ssot/vectors/` under the existing byte-check. The
new app-side tier is a **producer→consumer contract tier**: run real payloads through the real
transformers, feed the resulting rows to every consumer that derives or prices, assert the
ladder. Nothing in `qa/` needs a new folder; nothing in `app/` needs a new dispatch mechanism.

Blocked on: ⚖ Xuan ratifying the family (raised as `intake/2026-08-22-data-ssot-producer-shapes.md`).
Not blocked on: the ladder-unification fix itself, which is a plain bug fix against behaviour
the engine already implements correctly and ships ahead of ratification.

## Phase 6 — The ENGINEERING SSOT (twin computations: where they live, whose answer wins)

**Proposed by Xuan 2026-08-22.** A third kind of SSOT, orthogonal to the other two:

| family | answers |
|---|---|
| math (`spec/daily-macros`, `spec/fueling`, …) | what is the correct formula? |
| data (Phase 5, `spec/producers`) | what shapes do the inputs actually take? |
| **engineering (this phase)** | **where does a computation live, and whose answer wins?** |

**The proposed rule (Xuan's words, with two refinements):** *for functions that need a twin, the
server side must mirror the client side's payload and preempt the client's results.* Stated as
clauses:

0. **A twin exists only by ratification** (Xuan, 2026-08-22: *"the fact there is a twin side is
   also an engineering SSOT"*). Twinning is a permanent cost — two implementations, a parity
   burden that never expires, and a second answer that can diverge from the first. A computation
   is twinned only where a stated requirement demands it: offline capability, or feedback the
   athlete must see faster than a server round-trip. The justification is recorded in the twin
   registry alongside the pair. **Corollary:** a twin discovered in the code and not in the
   registry is a DEVIATION to log, never a fait accompli to absorb — which is precisely what the
   four independent duration ladders were (engine input builder, dashboard, onboarding insights,
   plan preview) before 2026-08-22. Nobody decided to have four; they accreted, and each new one
   was invisible to the others.

1. **Shape symmetry.** A twinned endpoint's RESPONSE must not be lossier than its REQUEST. If the
   client sends N sessions, it gets N results back, at the granularity it would otherwise compute
   locally, keyed so each maps to its input. A server that computes a value and drops it at the
   response boundary forces the client to recompute — which is how two answers to one question
   start existing.
2. **Server preempts — *while fresh*.** The server's result is authoritative and displaces the
   local one. **Refinement:** preemption is conditional on the cached result not being
   invalidated. A stale server answer describes inputs the athlete has since changed, so
   "preempt" must never mean "show a stale number" — where invalidation already exists (Q-016
   `invalidateFromDate`), an invalidated day falls back to the twin until the recalculation lands.
3. **The twin is the fallback, and stays parity-pinned.** The client implementation does not go
   away: it prices a just-added or offline session, must be visibly labelled an estimate, and
   must be superseded the instant a server result arrives. **Refinement:** because it survives,
   it stays pinned to the server implementation by parity vectors — the discipline that already
   keeps `sessionCost` honest across TS and Dart. Deleting the twin is not the goal; demoting it
   is.

A fourth clause worth ratifying alongside: **any locally-computed figure displayed beside
server-computed figures must be reconcilable** — a test asserts the displayed sum equals the
server's own total. That cross-check is the tripwire the whole 2026-08-22 episode lacked; it is
implemented for one surface already in
`app/test/contracts/session_pricing_producer_consumer_test.dart`.

### The concrete gap this family exists to close

`calculate-daily-macros-v6` violates clause 1 today, and the macro dashboard therefore violates
clauses 2 and 3:

- `pipeline.ts:587` maps every `ResolvedSessionData` down to source TAGS (`kcal_source`,
  `if_source`, `tss_source`, `duration_source`) and discards the per-session `session_kcal`,
  `duration_hr` and `intensity_factor` it has just computed. Request carries N sessions;
  response carries one day total plus N provenance labels.
- `dashboard_assembler.dart:362–370` therefore sums locally-computed cards for the workout total,
  while `targets.sessionKcal` — the engine's own answer, already cached on the device — is used
  only for weekly carb periodization (`:464`).
- `lib/features/macro_dashboard/` contains no connectivity check at all, so the twin is the sole
  source online and offline alike — the opposite of the intended fallback role.

Athlete-visible cost, measured on a real account 2026-08-22: a projected burn of 2,933 against a
3,037 fuel target on the same card, ~104 kcal apart, with the engine's own 1,394 sitting unused
on the device. Registered for post-ship verification as **`DEVIATIONS.md` D-005** — close it by
re-observing the app, not by reading the diff.

Proposed shape, reusing existing conventions:
- `spec/engineering/twin-computations.md` — the clauses, normative.
- `spec/engineering/twin-registry.md` — every twinned computation, its server home, its client
  home, **why it is twinned at all** (clause 0), its parity-vector slice, and whether the
  response is shape-symmetric today.
- Conformance: the existing parity vectors already pin clause 3; clauses 1 and 2 are pinned by
  contract tests in `app/` (the Phase-5 tier), dispatched as a normal slice.

### Where it lives: `qa/spec/` — mirrored, not relocated

Asked 2026-08-22: should this be a `qa/` spec family or an `app/` principle document? **Both, via
the mechanism that already exists** — authored and ratified in `qa/spec/engineering/`, mirrored
verbatim into `app/docs/ssot/spec/engineering/` under the same byte-check
(`conformance/run_dart.sh` `require_mirror`) that already carries the nutrition specs across.
No new mechanism, no second copy to drift.

Why authorship must sit in `qa/`, not `app/`:
- **Ratification only exists here.** The ⚖ gate, the intake loop, `DEVIATIONS.md`, versioned
  bundles — an "SSOT" outside that machinery is just a document, and documents lose to code.
- **"Implementation is not authorization" needs an author who isn't the implementer.** A rule
  about how app code must behave, authored in the app repo by the people writing that code, is
  the exact conflict of interest the two-repo split exists to remove. D-005 exists *because* an
  engineer made a reasonable local decision that contradicted unstated intent.
- **The verification target already lives here** (`DEVIATIONS.md` D-005). Rule and tripwire
  belong in one repo.
- **Bundles are the only versioning/gating channel** into `app/`. A rule in `app/docs/` cannot be
  tagged `@vN`, cannot appear in a handoff, and cannot gate a land.

Why it must nonetheless be *readable* in `app/`: it is consumed at coding time, next to
`docs/technical/foa-architecture.md` and `write-consistency-policy.md`. The mirror gives that for
free, and `app/CLAUDE.md` gets a one-line pointer under its docs map — a pointer, never a
restatement (CLAUDE.md's own standing rule).

**The test for which side a future rule falls on:** does it change what an athlete sees, or
whether the product tells the truth? → `qa/spec/`, ratifiable. Is it purely internal craft —
naming, folder layout, FOA layering, state-management choice — with no athlete-visible
consequence? → `app/docs/technical/`, no ratification needed. Twin precedence is emphatically the
first kind: it decided 2,933 vs 3,037 on a real athlete's screen.

Honest note on precedent: `app/docs/technical/write-consistency-policy.md` (offline-first vs
remote-ack) is the same genre and lives on the app side today. It sits on the line — a
coach-on-athlete write not appearing IS athlete-visible — so if this family is ratified, whether
that policy should migrate or be referenced is worth ruling at the same time rather than leaving
two homes for one kind of rule.

Blocked on: ⚖ Xuan ratifying the family (raised as
`intake/2026-08-22-engineering-ssot-twin-computations.md`). Note this phase requires an EDGE
FUNCTION change and therefore a deploy — unlike Phase 5's fix, it cannot ride a client-only
hotfix. The response change is purely additive, so old clients are unaffected and no coordinated
release is required.

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
