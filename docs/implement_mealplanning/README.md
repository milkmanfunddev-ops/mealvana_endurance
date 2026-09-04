# Implementing meal planning (Vana) in the app

Tracking home for turning the `mealplanning-prototype` into a paid, FOA-conformant feature of this app.
Research corpus + specs stay in `docs/new_mealplanning/`. Updated 2026-09-02 after Phase 5 (dev) + Phase 6 (tests).

| Doc | Phase | Status |
|---|---|---|
| `01-git-reconciliation.md` | 0 — branches, prototype self-contained, changelog | **done 2026-09-01** |
| `02-contract.md` | 1 — the frozen Dart↔TS contract (types, parts, actions, wire protocol) | **done 2026-09-01 — prototype tag `contract-v1`** |
| `03-backend.md` | 2 — `vana-chat` / `vana-action` / `vana-day-notes` edge fns + RPCs | **done on dev 2026-09-01** — see 03 §5 for deviations |
| `04-entitlement.md` | 3 — Pro entitlement: store products, `user_entitlements`, `subscription/` feature, gate | **built 2026-09-01 (dev only)** — see its Status table; prod DDL/webhook/app_config bump in Phase 5 |
| `05-flutter-feature.md` | 4 — `lib/features/meal_planning/`: file tree, Drift v20, reuse map, screen specs | **4a + 4b + 4c (presentation, router, tabs, content keys) done 2026-09-01** — see its Status section. Remaining in 4: simulator walkthrough; goldens + Patrol are Phase 6 |
| `06-sync-schema-envs.md` | 5 — sync registration, schema bumps, prod DDL + seed runbook | **dev side done 2026-09-02; prod apply prepared, NOT run** — see its Status table |
| `07-verification-release.md` | 6 — tests, Patrol, manual verification, dark launch | **tests done 2026-09-02** (goldens + 2 Patrol flows + runner script); release steps not started |

## NEXT SESSION STARTS HERE — Xuan's call on the prod apply, then the release
Branch `mealplanning`. Everything below the "Where we are" heading is history; the live state is:
- **Done:** Phases 0, 1 (prototype `contract-v1`), 2 (edge fns on dev), 3 (Pro entitlement on dev),
  4a/4b/4c (domain + data + application + Drift **v20** + sync registration + presentation/router/tabs/content),
  **5 dev-side** (schema bump to 20 on dev; prod runbook written and pre-checked against live prod),
  **6 tests** (goldens, two Patrol flows, `scripts/run-meal-planning-tests.sh`, edge suite 88/88).
- **Blocked on a human:** the prod DDL + seed + fn deploy (`supabase/migrations/cutover/meal_planning/`).
  Prod `app_config` and the prod apply are Xuan's call per the deploy playbook — the runbook is ready,
  nothing has been written to prod.
- **Simulator walkthrough: done 2026-09-02** (dev, QA user, iPhone 17 Pro). Food tab → New meal
  plan → opener (3 dinners, diet-respecting) → pick → plan bar + filter chips → Review → Confirm
  (`meal_plans.status='confirmed'`, 5 shopping items) → Plan tab tile → "Ate it"
  (`meal_logs source='plan'`, `servings_left` 4→3) → Shopping tab (5 rows + have-it + Share).
  **Two real bugs found and fixed on the walk:**
  1. **Content keys rendered raw** — nothing ever calls `ContentService.initialize()`, and a stale
     SharedPreferences cache beats the bundled JSON. `getValue` now falls back to the bundled
     defaults (`ContentDefaultsCache`, preloaded in all three `main()`s before `runApp` so
     first-frame widgets see real values), and `contentServiceProvider` kicks `initialize()` itself.
  2. **The chat opener vanished** — `loadOpener` fired in the screen's first post-frame callback,
     before the async notifier's `build()` Future resolved, so the initializer's return clobbered
     the turn state (every event then applied to an empty message list). `loadOpener` now
     `await future;` first. Instrumented-then-deinstrumented; trace in the session log.
  Cosmetic nit open: "1 meals picked" (no pluralization in the `{n} meals picked` template).
- **Next without a human:** the Phase 1 persona/walkthrough mismatches listed below.
- **Found on 2026-09-02, worth knowing before the release:**
  - Prod's migration ledger stops at `20260811160003`, so the meal-planning push also carries the two
    **2026-08-14 macro-dashboard migrations**. Prod is missing `activities.planned_time`/`actual_time`
    (it has `deleted_at`), and `plan_recalc_log` exists there but is not in the ledger. Both files are
    idempotent; both are needed by 1.24 regardless of meal planning.
  - Prod has **no `pgvector`** — the first migration creates it, so the apply must go through
    `supabase db push`, not the SQL editor.
  - **"Ate it" did not exist.** `logFromPlan` — the only plan → `meal_logs` bridge — had no UI entry
    point after 4c. Added to the plan tile sheet; it is the last assertion of the plan-build Patrol flow.
- Still open: the App Review screenshot for the two ASC subscriptions (needs the paywall UI, blocks
  `PRO_PURCHASE_ENABLED=true`); a sandbox purchase→webhook→flip run on a **release-mode** build (debug uses the RC
  Test Store key); the Phase 1 persona/walkthrough mismatches (prompts are verbatim `contract-v1`).

## Where we are (verified 2026-09-01)
- **Git**: `main` = v1.23.3; `develop` = `1.24.0+1` with all release commits; feature branch
  **`mealplanning`** = develop + 9 migrations + docs. Prototype repo committed, pushed, self-contained
  (`packages/web/{scripts,data}`). Sanity changelog 1.23.3 published. Xuan's unmerged branches listed
  in 01 — Lee is asking her.
- **DB**: dev has every meal-planning object (1,922 `meal_library` rows w/ steps, `meal_plans`,
  `plan_meals`, `user_memories`, `vana_*` + `jade_*` views, `meal_feedback`, all RPCs). **Prod has none**
  and still has real `jade_*` tables. Drift: develop v18.
- **Prototype**: TanStack Start + AI SDK v6 via AI Gateway; 24 tools in two sets, 22 UI actions, NDJSON
  is *not* what it streams (AI SDK UI stream) — the contract doc decides on the `jade-chat` NDJSON envelope
  for both clients. Full inventory of screens/components/tokens in the Phase 1 research (see 02, 05).
- **App reuse**: `ai_coach` chat stack (NDJSON stream, sealed `AiCoachUiPart`, 402 paywall) is the
  Vana chat's base; `meal_logging` repos/widgets; Kyle widgets; `SyncableRepository` pattern.
  Gaps: no `MealLogSource.plan`/`planMealId` in Dart yet; `KyleFoodIcon` has 12 types (need 23);
  `ai_coach` content keys were never registered; `kyle_design.dart` barrel is stale.
- **Paywall**: RevenueCat entitlement `pro` + monthly/annual products exist **only on the Test Store
  app**; no entitlement is read anywhere in Dart; `/pro` is a static screen; no `user_entitlements`.
- **Edge**: `jade-chat` already uses `npm:ai@6` streamText/tools under Deno with credits + Sentry —
  `server/vana/*.ts` ports nearly 1:1.

## Decisions (made; change here if they change)
1. Prototype stays in its repo as the living reference + contract fixtures; nothing TS is copied into
   `lib/`. SQL lives here.
2. Agent → Supabase edge functions (`vana-chat`, `vana-action`, `vana-day-notes`), not a Vercel service.
3. Wire protocol → the `jade-chat` NDJSON envelope (+ `status` lines), so the Flutter client is an
   extension of `ai_coach`, and `/jade` becomes `Vana · general`.
4. Gating → **Pro only** (decided by Lee 2026-09-01). Server-enforced via `user_entitlements`, client via
   `subscriptionStatusProvider`. Meal planning does **not** debit AI credits — Pro is the price. Feature
   ships dark on prod behind `PRO_GATE_ENABLED=true` until the paywall design exists. (Supersedes the
   monetization docs that listed meal planning as credit-gated.)
5. Local-first only for user-owned rows (`meal_plans`, `plan_meals`, `user_memories`, shopping ticks,
   settings). `meal_library` search/detail is online (in-memory cache). Pick/swap/confirm/log are
   remote-ack. Chat is online.
6. Drift v19 = plans + memories + entitlements + `meal_logs.plan_meal_id` + `saved_meals` extras.

## Phase 1 — finish the prototype + freeze the contract — **DONE 2026-09-01** (`mealplanning-prototype` `contract-v1` = `26990e2`)
All seven items landed (commits `6012088`…`26990e2`). Notables: rate limiting had been a no-op (bucket name mismatch) — fixed;
`save_meal` action added; fixtures for 13 shapes in `packages/web/tests/fixtures/`; 5.2 MB `data/meal-library.snapshot.json`.
**Walkthrough mismatches → Phase 2 persona work** (`persona.ts`/`OPENERS`, fix in the edge-fn port and back-port to the prototype):
- "Other options" can return a picker with no sentence; general turns stream pre-tool narration and skip `dayGuidance`
  (no snack card / carb target cited when nothing is scheduled).
- The batch-cooking fork never appears in chat ("Looks good" jumps straight to the lunch picker); the race-eve `proposeRule` needs a race.
- Step 10: after `setSetting(batch_cooking=false)` Vana asks "rebuild vs keep" instead of "for good or just next week".
- Plan tab day slots stay empty — decide whether `plan_day` auto-runs on first view (05 §4 says the Plan tab shows the plan list, not the grid).
- `walkthrough.md` step 2 still says staples are auto-added; behaviour is suggest-only (intended). Update the doc.
- `scripts/smoke-vana.test.ts` mutates the plan of whoever owns the first `saved_meals` row (Lee) — point it at the QA user.

Original task list:
1. Fix the known gaps: detail-sheet swaps applied via `apply_swap`; `dayGuidance` never returns the
   same saved meal for dinner + snack; the heart "Save to mine" wired; `getFoodHome` deleted (duplicate of
   `homePayload`); dead widgets removed (`BatchBar`, `CoverageMeter`, `LogRow`, `CommentThread`,
   `AdjustInput`); `reuseFreshOpener` either called or deleted; `vana.css` `--k-*` block replaced by
   `tokens.css` vars.
2. Add an NDJSON transport (`02 §5`) beside the AI SDK stream so the web client exercises the exact
   envelope the app will use; emit `status` lines.
3. Rate limit + `vana_calls` on every model path (opener, day notes, brief); buckets → `vana_calls`.
4. Add the app-only actions (`get_home`, `get_meal`, `recent_meals`, `set_saved_meal_notes`,
   `set_meal_feedback`) so `routes/-server/food.ts` server fns are thin wrappers over `actions.ts`.
5. `scripts/export_meal_library.mjs` → `data/meal-library.snapshot.json` (dev → file) and make
   `seed_meal_library.mjs --snapshot` load it (one-command prod seed, 06 §3).
6. Fixtures: `smoke-vana.test.ts` writes `tests/fixtures/{opener,picker,batch,confirm,home,meal}.json`
   for the Dart parser tests.
7. Walk steps 1–10 of `docs/new_mealplanning/walkthrough.md` against dev; `pnpm typecheck && pnpm test`;
   tag `contract-v1`.

## Phases 2–6
See the numbered docs. Sequencing and parallelism:
```
Phase 1 ✅ ──────┬── Phase 2 backend (4–5 d) ──┐
                  └── Phase 3 entitlement (3 d) ─┤   (2 ∥ 3; store product setup by Lee in parallel)
Phase 4 Flutter domain/data (3 d) can start right after Phase 1 (contract) ─┘
Phase 4 controllers + screens (2½ wk) needs Phase 2 deployed to dev
Phase 5 (2 d) → Phase 6 (1 wk) — prod DDL/seed can happen any time after Phase 2 (additive, dark)
```
Single engineer ≈ 7 weeks; with Xuan on the catalog/detail/cooking-mode screens ≈ 5.

## Open decisions
2. Dev/prod Apple product ids for the Pro subscriptions (team-unique rule) — see 04.
3. Whether `jade-chat` is kept as an alias for 1.23.x clients until `min_app_version` moves past 1.24
   (default: yes, one release).
4. Cooking-mode alarm: local notification vs in-app audio (default: `flutter_local_notifications` +
   vibration; no audio asset).
