# 07 — Verification & release (Phase 6)

## Status — **tests done 2026-09-02; the release steps are not started**
| Item | State |
|---|---|
| Contract / fixtures | **done** (4a) — `fixture_roundtrip_test.dart` + `vana_stream_event_test.dart` over the 13 frozen `contract-v1` fixtures in `test/features/meal_planning/fixtures/`; the same fixtures drive the edge contract test. |
| Drift migration | **done** — `test/migrations/meal_planning_v20_migration_test.dart` (v20, not v19). |
| Repositories | **done** (4b) — `meal_plan_repository_test`, `user_memory_repository_test`, `vana_chat_repository_test`, `vana_action_client_test`. |
| Controllers | **done** (4b) — plan, catalog, chat, cooking-session, plus `plan_coverage_service` / `meal_icon_classifier` / `cooking_step_timers` / `ui_action` in `domain/`. |
| Widgets | **done** (4c) — chips, part renderer, plan bar, shopping list. |
| **Goldens** | **done 2026-09-02** — `test/features/meal_planning/presentation/widget_goldens_test.dart`: plan (empty / draft / confirmed), meal picker + chips, plan bar (minimized / expanded), shopping list (populated / empty), each in **light and dark at iPhone-SE width**, driven by the `confirm_plan` / `shopping_list` / `meal_picker` wire fixtures. 18 goldens in `presentation/goldens/`. |
| **Edge** | **done** — `supabase/functions/tests/vana/{grocery,context,contract}.test.ts`, 12 tests, auto-discovered by `run-algorithm-tests.sh` (88/88 local files green on 2026-09-02). |
| **Patrol** | **done 2026-09-02** — `pro_gate_flow_test.dart` and `meal_plan_build_flow_test.dart` (see below). |
| **Screen + sheet tests (review pass)** | **done 2026-09-02** — `presentation/screens/plan_tab_test.dart` (empty/draft/confirmed states, day note from the `home` fixture, and the full "Ate it" wiring: tile → sheet → `logFromPlan` with success / offline / server-error snackbars, through fake notifiers over the real screen); `widgets/tile_sheet_test.dart` (Ate it shown / hidden at `servingsLeft == 0` / absent with no handler; stepper, Swap, Remove intents); `widgets/servings_stepper_test.dart` (min/max clamps, disabled inertness). |
| Manual `/verify-app` walkthrough | **not done** — the simulator pass is its own session. |
| Release (merge, cut, prod) | **not started.** Phase 5's prod runbook must land first. |

### Deviations from the test plan above (and why)
- **Goldens are widget-level, not screen-level.** `matchesGoldenFile` on `PlanTab` /
  `MealDetailScreen` / `CookingModeScreen` would mean faking four controller providers plus a
  router per case, to photograph compositions of the same widgets the file already covers. What
  it would add — the private `_EmptyPlanCard`, `_OriginBadge` and the cooking step chrome — is
  reachable more cheaply once those move into the library. Recorded rather than silently skipped.
- **Goldens pin layout, colour and structure — not glyphs.** Widget tests render with the test
  font, so the text is boxes. That is the right regression surface here (a token swap, a padding
  change, a state that stops rendering); typography review stays a `/verify-app` job.
- **`meal_plan_build_flow_test.dart` is NOT in any CI target list.** Every turn of it calls
  `vana-chat` / `vana-action`, i.e. real model spend on every push — exactly why
  `ai_coach_chat_flow_test` is kept out of `codemagic.yaml` and
  `.github/workflows/tests-selfhosted.yml`. It self-skips on prod and is run by hand.
  `pro_gate_flow_test.dart` **is** registered in both (and `EXPECTED_PATROL_TESTS` 24 → 25):
  it makes no model calls and never skips except with no credentials.
- **The Pro-gate flow asserts an invariant, not the paywall.** Dev builds force
  `PRO_GATE_ENABLED=false`, so on the only environment Patrol runs in, every athlete is unlocked
  and "the locked user sees `/pro`" would be red on every run. The flow instead pins that the tab
  and the routes agree: tab visible → `/food` and `/vana` open the feature; tab hidden → both
  redirect to `/pro`. A half-applied gate fails in either build.
- **The cutover verify SQL had a stale index name.** First cut checked `meal_plans_active_week`;
  `20260831150000` drops that and creates `meal_plans_confirmed_week`. Caught by running
  `90_verify.sql` against live dev (it must read all-green there, since dev IS the applied state) —
  fixed, and the runbook's expected block now matches a real dev run line for line.
- **"Ate it" did not exist.** `MealPlanController.logFromPlan` (the only plan → `meal_logs`
  bridge, and the last assertion of the plan-build flow) had **no UI entry point** after 4c — the
  `meal_planning.ate_it` / `logged_done_toast` content keys were unused. Added to the plan tile
  sheet (`meal_planning.tile_sheet.ate_it`), remote-ack, hidden when `servingsLeft == 0`.

## Running the suites
`./scripts/run-meal-planning-tests.sh` runs every layer, or any subset:
`domain`, `data`, `app`, `widget`, `content`, `migration`, `edge`, `patrol`
(`unit` = domain+data+app; no argument = everything but patrol). `--list` prints them,
`--update-goldens` re-records. The layers are plain `flutter test <path>` / `deno test`
invocations, so a green layer here is green in CI, and CI's bare `flutter test` still sweeps all
of it — the Flutter layers all live under `test/`, which is the gate (`docs/test/README.md`).

## Tests (add as each phase lands, not at the end)
- **Contract**: `test/features/meal_planning/domain/vana_part_parse_test.dart` — every `VanaPart` kind
  and `MealRef`/`MealPlan` round-trips fixtures exported from the prototype (`packages/web/tests/
  fixtures/*.json`, generated by `smoke-vana.test.ts`). Same fixtures drive the edge-fn contract test.
- **Drift**: v18→v19 `SchemaVerifier` migration test; `MealPlanRepository` local-first edit →
  `needs_upload` → `uploadDirtyRecords` upsert `onConflict:'id'` (mock PostgREST) → result checked.
- **Controllers**: `MealPlanController` (servings/remove local-first; pick/confirm remote-ack;
  offline paths), `VanaChatController` (opener, stream fold of `batch` parts, 402/403/429 mapping,
  chip disable state), `MealCatalogController` (debounce, filters), `CookingSessionController`
  (`findDurations` cases, phase machine, timers), `MealIconClassifier` (table-driven from the TS spec),
  `PlanCoverageService`, `SubscriptionStatusProvider` (RC ∪ server row ∪ internal flag).
- **Widgets/goldens**: Plan tab (empty, draft, confirmed), Meal picker + chips, Plan bar (minimized /
  expanded), Shopping list, Meal detail (each `directions_origin` badge), Cooking mode step —
  `matchesGoldenFile` (the alchemist mention in the testing doc is stale).
- **Edge**: vana suite in `run-algorithm-tests.sh` (03 §2.8).
- **Patrol** (`integration_test/flows/`): `meal_plan_build_flow_test.dart` — sign in → Food → New meal
  plan → opener → tick 2 dinners → Next → Confirm → Shopping shows items → Plan tab shows tiles →
  Ate it → `meal_logs` row (`supabase_probe`). `pro_gate_flow_test.dart` — gated user sees `/pro`.
  Credentialed providers are Android-only per memory; these two are provider-free.

## Manual verification
`/verify-app` on the simulator against dev with the QA user; walkthrough steps 1–10 from
`docs/new_mealplanning/walkthrough.md`; dark + light; iPhone SE width; web build (`:8080`) for the rail.

## Release
1. `/task-checker` on `mealplanning`; `flutter analyze` 0 errors; `flutter test` green.
2. Merge `mealplanning` → `develop` (PR, Xuan review); `/cut-build` dev → `/release-cut` card;
   `/sprint-sync`.
3. Prod: Phase 5 runbook first (DDL + seed + fns), then the app release with `PRO_GATE_ENABLED=true`
   — feature ships **dark** (no Food tab) until the paywall design + store products are live; flip by
   granting `pro` entitlements / enabling purchase.
4. Changelog entry auto-publishes on the `main` merge — review it (date, no tester SKUs).
5. Memory + docs: update `docs/README.md` map, `EDGE_FUNCTION_AUDIT.md`, `docs/database/README.md`
   (new tables), and archive `docs/new_mealplanning/prototype-rebuild-spec.md` as historical.
