# Implementing meal planning (Vana) in the app

Tracking home for turning the `mealplanning-prototype` into a paid, FOA-conformant feature of this app.
Research corpus + specs stay in `docs/new_mealplanning/`. Updated 2026-09-01 after Phase 0.

| Doc | Phase | Status |
|---|---|---|
| `01-git-reconciliation.md` | 0 — branches, prototype self-contained, changelog | **done 2026-09-01** |
| `02-contract.md` | 1 — the frozen Dart↔TS contract (types, parts, actions, wire protocol) | spec ready |
| `03-backend.md` | 2 — `vana-chat` / `vana-action` / `vana-day-notes` edge fns + RPCs | spec ready |
| `04-entitlement.md` | 3 — Pro entitlement: store products, `user_entitlements`, `subscription/` feature, gate | spec ready |
| `05-flutter-feature.md` | 4 — `lib/features/meal_planning/`: file tree, Drift v19, reuse map, screen specs | spec ready |
| `06-sync-schema-envs.md` | 5 — sync registration, schema bumps, prod DDL + seed runbook | spec ready |
| `07-verification-release.md` | 6 — tests, Patrol, manual verification, dark launch | spec ready |

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

## Phase 1 — finish the prototype + freeze the contract (1–2 days, prototype repo)
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
Phase 1 (proto) ──┬── Phase 2 backend (4–5 d) ──┐
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
