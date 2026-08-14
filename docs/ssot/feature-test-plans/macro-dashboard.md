# Feature test plan — Macro Dashboard (daily calculation + workout cards)

- **Feature:** the `daily-macros-dashboard@v1` bundle scope — daily macro calculation engine + the
  dashboard surface with workout cards. Excluded per bundle: post-workout, daily-insight AI card,
  safety-state UI, phase chip, sodium display.
- **Status:** DRAFT (2026-08-14, drafted pre-freeze, pre-implementation of the new contracts)
- **Source documents:** `spec/daily-macros/` (9 sections, RATIFIED v1) · `spec/fueling/post-workout.md`
  (ratified, EXCLUDED from bundle) · `spec/design/` (4 docs, RATIFIED v1) ·
  `prototypes/macro-dashboard/index.html` @ `aa81d21` · vectors: `vectors/daily-macros/*.json` (168) ·
  design manifests: `conformance/design/macro-dashboard.{goldens,gestures}.yaml`
- **App test taxonomy:** `$APP_ROOT/docs/test/README.md`; layers per `docs/test-layering-plan.md`

## 1. Invariants

| # | Invariant (testable) | Owning document | Pinned by |
|---|---|---|---|
| I1 | Fat is 0.8 g/kg ≤ fat ≤ 30 %E except the both-caps corner; step 10b conserves energy exactly | assembly.md I8/I10 | ⬜ (vectors `assembly.json` exist; engine runner ⬜) |
| I2 | A workout row's `planned_time` is never mutated by any gesture; `actual_time` is null unless Garmin or mark-done wrote it | platform-resolution.md | ⬜ |
| I3 | A `status='deleted'` row survives every sync and never renders anywhere | platform-resolution.md + intraday-display §4b | ⬜ (vector `tombstone-matcher`; db path ⬜) |
| I4 | Every number on the dashboard maps to a spec field; no surface disagrees with another on the same quantity | intraday-display P-3 / surface S-3 | ⬜ |
| I5 | No rendered copy states an unconditional refueling deadline, in any state | surface S-6 | ⬜ (manifest `s6_no_unconditional_deadlines`) |
| I6 | Every `recalculateAfterSync` writes exactly one `plan_recalc_log` row | platform-resolution.md (calibration ruling) | ⬜ |

**Seed-question findings (durability/identity/symmetry):**
- **Identity — RULED (Xuan, 2026-08-14):** match key = platform activity id, falling back to
  platform+sport+start-time ±15 min (`[design]` window). One definition governs tombstone matching
  AND re-sync dedup. Pinned by `tombstone-matcher*` vectors (3).
- **Durability — OWNED BY NONE, blocking:** `planned_time`/`actual_time` columns and the
  `plan_recalc_log` table exist in **no migration** (verified: zero hits in `supabase/migrations/`
  and the edge function). The specs assert "Supabase carries both columns"; nothing owns creating
  them. Schema work must be an explicit implementation task in the bundle's done_when.
- Symmetry: mark-done ↔ mark-undone pinned (manifests g1/g2). Delete has no undo — accepted (W-4
  noted; ruled tolerable for this iteration? **not explicitly ruled — carry as open**).

## 2. Chains

### Chain: the plan is computed

`profile + sessions + platform data → resolve (F22–F27) → pipeline (baseline…10b) → EA gate → returned plan`

| Link | Failure mode it can hide | Owning doc | Cheapest layer | Pinned by |
|---|---|---|---|---|
| profile → engine inputs | Garmin body-comp update ordering; stale weight in g/kg math | platform-resolution.md | contract | ⬜ |
| resolution ladders | wrong source wins; prospective uses Garmin | platform-resolution.md | unit | ⬜ vectors `platform-resolution.json` (17) await runner |
| pipeline math | any of the 15 ruled behaviors regressing | 8 spec sections | unit/parity | ⬜ vectors (127) await runner; **existing engine tests pin PRE-RULING behavior — see §5** |
| EA gate + override | ceiling breach; gate ordering vs 10b | energy-availability.md, assembly.md | unit | ⬜ vectors exist |
| plan → dashboard targets | targets drift from engine output | intraday-display P-3 | widget | ⬜ |

### Chain: workout card lifecycle (the bundle's second half)

`scheduled → PLANNED card → swipe-done (actual_time=now) → burned updates → Garmin sync → MANUAL→GARMIN upgrade → F27 recalc → plan replaced → plan_recalc_log row`

| Link | Failure mode it can hide | Owning doc | Cheapest layer | Pinned by |
|---|---|---|---|---|
| gesture → state + write | wrong column written; planned_time clobbered | design G1/G2 + platform two-time | widget + db-flow | ⬜ manifest g1/g2 |
| verified suppression | Garmin fact contradicted by swipe | design G3 | widget (negative) | ⬜ manifest g3 |
| write → Supabase schema | **columns don't exist** | **NONE** (see invariants) | migration + db-flow | ⬜ **blocked on schema** |
| state → whole-dashboard update | local repaint only; sheets stale | design G7 + surface S-1 | widget | ⬜ manifest g7 |
| sync upgrade MANUAL→GARMIN | double-count; actual_time not overwritten | platform-resolution.md | seam | ⬜ manifest |
| recalc replaces today | delta wrong; energy_basis lost | platform-resolution F27 | contract | ⬜ vectors end-to-end |
| recalc → log row | calibration data silently missing | platform-resolution (ruling 1/5) | db-flow | ⬜ **blocked on schema** |

### Chain: deletion stays deleted

`swipe-left → Delete press → status='deleted' write → surfaces update → next sync → matcher hits tombstone → no re-import`

| Link | Failure mode it can hide | Owning doc | Cheapest layer | Pinned by |
|---|---|---|---|---|
| gesture → soft delete | hard DELETE shipped instead | design G4/G5 + platform ruling | db-flow | ⬜ manifest g5 |
| removal propagation | one surface keeps the kcal | surface S-2 | widget | ⬜ manifest |
| sync matcher vs tombstone | filter-before-match reintroduces reappearance | platform-resolution.md | seam | ⬜ vectors (3, incl. fallback key + outside-window) await runner |

### Chain: intraday display

`plan + day log → §1 accrual → energy-card faces → band copy`

| Link | Failure mode it can hide | Owning doc | Cheapest layer | Pinned by |
|---|---|---|---|---|
| accrual arithmetic | clock-smeared sessions; phantom NEAT | intraday-display §1 | unit | ⬜ vectors `intraday-display.json` (24) await consumer |
| faces render targets | P-2 "fixed" by a helpful editor | energy-card spec | golden | ⬜ manifest (10 goldens) |
| band copy | wrong register string; surplus under pre_override | intraday-display §2 | unit (string) | ⬜ vectors band-* |

## 3. Vectors wanted

| Contract | Vector file | Consumed by |
|---|---|---|
| Engine math, 8 slices | ✅ `vectors/daily-macros/*.json` (144) | engine runner (⬜ to build) |
| Intraday display arithmetic | ✅ `intraday-display.json` (24) | display consumer (⬜) |
| Goldens + gestures | ✅ manifests in `conformance/design/` | app test tree (⬜) |
| Workout-row serialization (draft → Supabase row incl. both time columns + status) | ⬜ | db-flow tests |
| Tombstone match key | ✅ `platform-resolution.json` tombstone-matcher* (3) | seam test (⬜ runner) |

## 4. Known-unpinnable
- Real Garmin push cadence/staleness (the NEAT bridge constant) — modeled, not verifiable in CI.
- Actual pixel fidelity beyond goldens' pinned environment (device-farm variance) — port-prompt
  side-by-side owns it manually.

## 5. Standing rules — status for this feature

*Drafted 2026-08-14, pre-freeze. No audit yet.*

- **The four existing engine test files (`index.test.ts`, `index.integration.test.ts`,
  `iteration5.test.ts`, `parity-fixtures.test.ts`) pin PRE-RULING behavior** — uncapped fat
  residual, 40 g strength hours, TP-first tomorrow, F19 rounding. They will go red against the
  ruled specs *correctly*. They must be updated to the vectors, not the vectors to them
  (spec-to-vectors governance). Treat their current green as pinning the superseded engine.
- Existing widget tests (`macro_card_screenshot_test.dart` + goldens, `fuel_timeline_*`) predate
  the design contracts; audit against the manifests during implementation — likely partial
  false-pins for the new card states.
- **One remaining owned-by-NONE item:** the schema migration (`planned_time`, `actual_time`,
  `status`, `plan_recalc_log`) — named in the bundle manifest's conformance note as an explicit
  implementation task. (The match key was ruled 2026-08-14 and is off this list.)
