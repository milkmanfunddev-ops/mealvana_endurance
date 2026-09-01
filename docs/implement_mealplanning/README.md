# Implementing meal planning (Vana) in the app

Written 2026-09-01 from a research pass over the Flutter repo, the prototype repo, the live dev/prod
Supabase projects, and the RevenueCat/entitlement code. This folder is the tracking home for the
integration; the research corpus and prototype specs stay in `docs/new_mealplanning/`.

| Doc | What it is |
|---|---|
| `README.md` (this) | Where things stand, the decisions, and the phased plan |
| `01-git-reconciliation.md` | Step-by-step plan for getting main/develop/release straight and the meal-planning work onto a feature branch (Phase 0) |

Phases 1–6 get their own doc as each starts.

---

## 1. Where things stand (2026-09-01)

### Code locations
- **Prototype (TS)**: `~/development/mealplanning-prototype` — TanStack Start + React 19 + AI SDK v6 via
  Vercel AI Gateway + Supabase (dev project `vlmtsdzpnjnavdgytcmi`). On `main`, in sync with
  `github.com/lbm54/mealplanning-prototype` at `1df9b3d` (2026-05-18). **The entire Vana rewrite
  (server/vana, components/vana, all `food.*`/`vana*` routes, settings) is uncommitted** — 85 deletions,
  26 new paths, 7 modified. `~/development/mealplanning_prototype` (underscore) is a dead May copy.
- **Flutter repo (this one)**: untracked on `release/1.23.1`: 9 Supabase migrations
  (`20260827090000` … `20260901160000`), 7 data-pipeline scripts (`scripts/*_meal_*.mjs` etc.),
  `docs/new_mealplanning/` (17 MB), a `.gitignore` line for `.cache/` (122 MB, ignored), and a stale
  regeneration of `docs/dev_schema.txt` / `docs/prod_schema.txt`.
- Coupling between the two: the 7 scripts default `--env` to
  `~/development/mealplanning-prototype/packages/web/.env.local`; both read/write the same dev DB.
  Nothing imports across repos.

### Database
- **Dev has all 9 migrations applied** (verified live): `meal_library` 1,922 rows (1,675 assembly /
  247 recipe, all with `method_steps`, pgvector embeddings), `meal_plans` (`days`, `day_notes`,
  `conversation_id`), `plan_meals`, `user_memories`, `vana_conversations`/`vana_messages`/`vana_calls`
  (with `jade_*` compat views), `meal_feedback`, RPCs `search_meals`, `match_library`,
  `recall_memories`, `library_pair_support`, `set_meal_feedback`. `docs/dev_schema.txt` is a stale dump.
- **Prod has none of it.** Prod still has real `jade_conversations`/`jade_messages` tables.
  `app_config`: dev `current_schema_version=18`, prod `18` (`min_supported=11`, `min_app_version=1.23.1`).

### Flutter app facts that shape the port
- Drift `schemaVersion` is **18 on develop** (17 on `release/1.23.1`). Manual `onUpgrade` ladder in
  `lib/shared/database/app_database.dart`; the sync-architecture doc's "delete & resync" model is not
  what the code does.
- Exemplar offline-first feature to copy: `lib/features/meal_logging/` (domain → data repo implementing
  `SyncableRepository` with PostgREST `upsert(onConflict: 'id')` → application → `@riverpod`
  AsyncNotifier controllers → screens). New repos register in `SyncDependencyGraph` **and**
  `SyncCoordinator._repositoryFor()` (`lib/shared/services/sync/sync_coordinator.dart`).
- Tabs are a hand-indexed custom shell (`lib/shared/widgets/tabs_screen.dart`): mobile = Fuel Timeline
  · Events · Learn; web adds Coach. Adding a tab touches index math in ≥3 places + `/main?tab=`.
- Jade chat = `lib/features/ai_coach/` (route `/jade`, edge fn `supabase/functions/jade-chat`), still
  writes `jade_conversations` (a view on dev, a table on prod).
- Flutter has **no meal detail screen and no cooking mode** — greenfield.
- Paywall: RevenueCat is wired **only for consumable credit packs** (`lib/features/ai_credits/`,
  offering `'credits'`, `token_wallets`/`token_ledger`, `revenuecat-webhook` → `grant_credits`). No
  entitlement is read anywhere; `users` has no tier column; `/pro`
  (`lib/features/pro_version/…/pro_version_screen.dart`) is a static "Coming Soon" screen.
  `docs/features/revenue_cat/README.md` describes a `features/subscription/` module that was never built.
- Runtime toggles that exist: `AppConfig` dart-define/dotenv booleans (`describeMealEnabled` already
  gates `/jade` + `/buy-credits` via a router redirect), `internalDeviceFlagProvider` (tester mode),
  the `app_config` Supabase table (version gating only).

### ⚠️ Decision conflict to resolve
`docs/features/revenue_cat/README.md` and
`docs/new_mealplanning/notion/gamification-and-monetization-strategy.md` list meal planning as a
**credit-gated feature, explicitly "NOT Pro"**. Lee's 2026-08-31 direction is **Pro-gated**. This plan
does Pro-gated *and* keeps per-turn credits metering (the prototype already logs every model call to
`vana_calls`), so both can be true. Confirm before Phase 3.

---

## 2. Decisions / recommendations

1. **Prototype stays in `mealplanning-prototype` and becomes self-contained.** The data-pipeline
   scripts and the JSON libraries they consume move there (`scripts/` + `data/`); the SQL migrations
   stay in the Flutter repo (they are the app's schema) but the prototype README points at them. The
   Flutter repo keeps only migrations + docs.
2. **Trim what is committed to `docs/new_mealplanning/`.** Specs, libraries (`*.json`/`*.md`), Notion
   transcriptions, `figma/*.md` stay. `direction-batches/`, `direction-results/`,
   `source-scrape.json`, `meal-images.json` are one-shot pipeline artefacts already applied to dev —
   move to the prototype repo's `data/` (they belong to the scripts) rather than this repo.
3. **Vana's agent becomes a Supabase edge function (`vana-chat`)**, not a Vercel service. Matches
   `jade-chat`, the AI Gateway key is already an edge secret, `ensure-credits` metering exists, one
   deployment target. `server/vana/{persona,tools,actions,context,grocery,daynotes,memory,embeddings,
   rate-limit,log}.ts` port to Deno with light edits (AI SDK v6 via `npm:` specifiers; caller JWT + RLS
   instead of service-role + userId filters). The 19 non-model `UiAction`s become Postgres RPCs or a
   small `vana-actions` fn.
4. **Gating = a real RevenueCat entitlement `pro` mirrored server-side** (`user_entitlements` table
   written by a new branch in `revenuecat-webhook`), a `subscriptionStatusProvider`, a router redirect
   on `/food/*` shaped like the `describeMealEnabled` one, the Food tab absent from `tabs_screen.dart`
   when not pro, and edge functions checking `user_entitlements` too. Dev/testers bypass via
   `internalDeviceFlagProvider` or `AppConfig.proGateEnabled`. Paywall design comes later; `/pro` is the
   interim destination.
5. **Local-first scope (Drift v19)**: local tables for `meal_plans`, `plan_meals`, `user_memories`;
   `meal_library` is **not** mirrored locally (`search_meals` is server-side pgvector); conversations
   stay server-authoritative like `ai_coach`. Plan **Confirm** requires remote ack before the shopping
   list is shown.

---

## 3. The phased plan

### Phase 0 — Git reconciliation (see `01-git-reconciliation.md`)
Outcome: `main` == last shipped release; `develop` carries everything incl. the release-only commits and
Xuan's stranded fixes; `feature/meal-planning` off the new develop holds the migrations + docs; the
prototype repo is committed, pushed, and self-contained; the 1.23.x changelog entry exists in Sanity.

### Phase 1 — Finish the prototype (1–2 days)
Known gaps: swaps chosen on the detail sheet aren't applied via `apply_swap`; `dayGuidance` can return
one saved meal for dinner + snack; library macros not catalog-grounded; `meal_library.source` is
attribution, not a recipe (14/247 had a real recipe page); og:image is usually the athlete; HMR drops
the live turn. Wire rate-limit + `vana_calls` logging on every model path. Smoke the walkthrough
(steps 1–10) against dev. **Freeze the contract** (`packages/web/src/lib/vana/contracts.ts`:
`MealRef`, `MealPlan`, `VanaPart`, `UiAction`, `AthleteContext`) — Flutter codes against it.

### Phase 2 — Backend (3–4 days)
1. `supabase/functions/vana-chat` — port context/persona/tools/memory/embeddings/rate-limit/log. Caller
   JWT; credits debit via `ensure-credits`; entitlement check against `user_entitlements`; stream
   UI-message parts the way `jade-chat` does so the Flutter chat client is shared.
2. `vana-actions` fn or RPCs: `confirm_plan`, `swap_meal`, `set_day_slot`, `plan_day`, `pick_meals`,
   `log_from_plan`, memory CRUD, `set_setting`.
3. `generate-day-notes` fn triggered on plan change; `day_notes_stale` semantics kept; never awaited inline.
4. Shopping list (`grocery.ts`) → Postgres function or inside `confirm_plan`.
5. Icon classifier → Dart mapping; DB `icon` columns stay as the cache.
6. `jade-chat` + `ai_coach` repointed to `vana_conversations` with `kind='general'`; the prototype's
   `general` persona replaces Jade's (finishes the Jade→Vana rename).
7. Tests ported (`grocery.test.ts`, `context.test.ts`) into `run-algorithm-tests.sh`;
   `EDGE_FUNCTION_AUDIT.md` updated.

### Phase 3 — Pro entitlement infrastructure (2 days, parallel with Phase 2)
1. RevenueCat: `pro` entitlement + `pro` offering with placeholder monthly/annual products (dev and
   `_prod` SKUs — product ids are team-unique). Sandbox only for now.
2. DB: `user_entitlements(user_id, entitlement, active, expires_at, source, updated_at)` + RLS;
   webhook branch for subscription event types (consumable path untouched; keep the webhook env-unfiltered).
3. Flutter: `lib/features/subscription/` — `subscription_service.dart` (mirrors
   `revenuecat_service.dart` conventions), `subscriptionStatusProvider` (`@Riverpod(keepAlive: true)`,
   `CustomerInfo.entitlements.active['pro']`, refreshed by `addCustomerInfoUpdateListener` set up next to
   `_initializeRevenueCat()` in `app_startup_service.dart`), `Entitlement` domain enum,
   `AppConfig.proGateEnabled` kill switch, router redirect `/food/*` → `/pro`, `pro_version_screen`
   fetches the real offering + restore (purchase disabled until design lands).
4. Tester bypass: `internalDeviceFlagProvider` **and** an RC promotional grant path so QA can test
   without sandbox purchases.

### Phase 4 — Flutter feature `lib/features/meal_planning/` (2–3 weeks)
- **domain**: `MealRef`, `MealPlan`, `PlanMeal`, `DayNote`, `VanaPart` (sealed), `UiAction`,
  `UserMemory`, `MealFeedback` — 1:1 with the frozen TS contract.
- **data**: Drift tables `meal_plans`, `plan_meals`, `user_memories` (+ `needs_upload`,
  `local_updated_at`, `is_deleted`); `MealPlanRepository`, `UserMemoryRepository` implementing
  `SyncableRepository`; `MealLibraryRemoteDataSource` (RPCs `search_meals`, `library_pair_support`,
  `set_meal_feedback`); `VanaChatRepository` (extend `ai_coach_chat_repository.dart`). Drift **v19** on
  top of develop's v18; onUpgrade step; `schema_versions.dart`; codegen.
- **application**: `MealPlanController`, `PlanDayController`, `MealCatalogController`,
  `ShoppingListController`, `VanaChatController` (`@riverpod` AsyncNotifier + `AsyncValue.guard`),
  `MealIconClassifier`, `PlanCoverageService`.
- **presentation**: Food tab (Plan · Meals · Shopping; Formulas links to the formula kit); Plan tab v2
  (day note + icon tiles + swipe swap/remove); Meals (Recents → My Foods → Assemblies → Recipes rails,
  search/filter); Meal detail (+ How to cook, user directions, thumbs); **Cooking mode**
  (`/food/cook/:id`, steps/timers/wake lock); Shopping (aisles, have/checked, share); Vana chat (opener
  frame + 3 dinners, client-drawn picker chips, minimized plan bar with ×/steppers, Review sheet →
  Confirm); Settings (batch cooking, show macros, "what Vana knows"). Copy via ContentService defaults;
  `MealvanaSnackbar`; Kyle tokens (`docs/new_mealplanning/design-system/tokens.css` ↔ `AppColors`).
- **router/tab**: new tab in `tabs_screen.dart` (mobile + rail), `/main?tab=food`, `/food/...` routes,
  pro-gate redirects.

### Phase 5 — Sync, schema, environments (2 days + cutover)
1. Register repos in `SyncDependencyGraph` + `_repositoryFor`; on-demand `ensureSynced('meal_plans')`
   from the Food tab (no startup sync-all); pre-logout sync; `delete-user` drops the new per-user rows.
2. `app_config` bump `current_schema_version=19` (dev, then prod); `min_supported` unchanged.
3. **Prod DDL**: apply migrations 1–9 in order (6 depends on 2's rename) to `wvmvsodrvbkxfydabqed`;
   seed `meal_library` on prod (≈1,922 embedding calls) and refresh `meal_library_pairs`; deploy the new
   edge functions to both refs; then regenerate `docs/*_schema.txt` properly.
4. Cutover runbook in `supabase/migrations/cutover/` style (prod gets the `jade_*` rename).

### Phase 6 — Verification & release (1 week, overlapping)
Unit + widget tests per controller; golden for Plan tab; Patrol flow opener → pick → confirm → shopping;
edge-fn tests; `/task-checker`; `/verify-app`; dev cut via `/cut-build` + `/release-cut`; `/sprint-sync`.
Ships **dark on prod** behind `proGateEnabled=false` / no entitlement until the paywall design exists.

---

## 4. Open decisions
1. Pro-gated vs credit-gated (or both) — see §1.
2. develop's version after reconciliation (`1.24.0+1`?) — coordinate with Xuan.
3. Edge function vs keeping the TS service on Vercel (recommend edge; counter-argument is AI SDK v6
   ergonomics under Deno).
