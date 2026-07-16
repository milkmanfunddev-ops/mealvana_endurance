# Food Search & Scan Architecture Audit

> # ▶ START HERE — resuming cold (after a context clear)
>
> **You need no prior conversation. Everything is in this file.**
>
> 1. Read **§0a DECISION LOG** — the 10 decisions + the 3 claims that were wrong. Do not re-litigate them.
> 2. Read **§10 MERGED ROADMAP** — the plan of record. (§9 is superseded; the 7-03 doc's §7 is superseded.)
> 3. Work the phases **in order**. Each shrinks the next.
>
> ## IMPLEMENTATION STATUS — updated 2026-07-16, on `develop` @ `67782d26` (pushed)
>
> | Phase | Status |
> |---|---|
> | **0 — land the two branches** | ✅ **DONE** (Lee merged them locally; merge verified — both fixes intact, no conflict markers) |
> | **1 — scored catalog search** | ✅ **DONE + DEPLOYED dev AND prod.** `search_catalog_ranked` RPC + `search-catalog` rewritten. Verified on prod: all 7 recoverable misses + `nuun electrolyte tablets` + `clif shot bloks` return the right top hit; `banana bread` → 0. Verified in-app: `rx bar` → 26 results, RXBAR #1 (was 0). |
> | **2 — dead code + render fix** | ✅ **DONE.** `functions_old` deleted (7,633 lines). `onNutritionProductResultTap` forwarded → verified in-app: `pringles` on food logging now returns results with carbs (was "No foods found"). `build_meal_add_food` barcode no longer shows the run-phase picker. |
> | **3 — one search fn + live FDA** | ⏳ **PARTIAL.** OFF silent-failure + retry/backoff DONE. **NOT done:** `_shared/food_sources/` extraction, `search-foods` merge, live USDA text tier, Search-a-licious migration, catalog `product_type` filter passthrough. |
> | **4 — carb loading** | ⏳ **PARTIAL.** Barcode crash fixed; hardcoded 30g fixed. **NOT done:** delete `carb_loading_user_foods` (needs a Drift migration + backfill — see the data-loss warning), delete `CarbFoodsList`, `setFilter`, de-dupe `_parseMealTypesArray` (3 copies). |
> | **5 — sport-aware categories** | ❌ **NOT STARTED** (386 occurrences / 71 files; mapper-first). |
> | **6 — structural debt** | ❌ **NOT STARTED.** |
>
> Commits: `2b209dc3` (Phase 1), `badd4920` (Phase 2), `0706b072` (carb loading), `67782d26` (OFF retry).
>
> **Next action = Phase 3**: extract `_shared/food_sources/` with zero behaviour change, verify barcode still works, commit — *then* build `search-foods` on top.
>
> **✅ AUTHORIZED (Lee, 2026-07-16) — do these unattended, no approval needed:**
> deploy edge functions to **dev AND prod**, run **DB migrations**, **merge to `develop`**, and do the `carb_loading_user_foods` fold. Verified: `supabase` CLI 2.90.0 authed (dev `vlmtsdzpnjnavdgytcmi` linked, prod `wvmvsodrvbkxfydabqed` visible), Deno 2.7.11, push access to `origin`.
>
> **⚠️ These are SEQUENCING rules, not permission gates — they're about not breaking things, so still follow them:**
> - **Dev → verify → prod.** Never deploy an edge fn straight to prod; prove it on dev first. (Both get deployed — just in that order.)
> - **`carb_loading_user_foods` is DEVICE-LOCAL and has NEVER synced** (no `needs_upload` column; absent from `SyncDependencyGraph`). Its rows exist **only** in Drift on users' phones. So the Drift migration **MUST backfill those rows into `user_foods` in the same `onUpgrade` step before dropping the table** — there is no server copy to restore from. Drop-without-backfill = silent, permanent loss of every user's custom carb foods. The Supabase-side table is safe to drop (it was never written to).
> - **Drift `onUpgrade` must be idempotent** — web `user_version` doesn't persist, so it re-runs. See `project_web_db_migration` (dup-column crash, commit `ef215509`).
> - **`onConflict: 'id'` only** on `user_foods` upserts — partial unique indexes throw 42P10.
>
> **Re-verify before trusting any line number here** — accurate as of `develop` @ `856d5005`, 2026-07-16.
>
> **Reproduce the key measurements yourself** (read-only, ~1 min) — prod ref `wvmvsodrvbkxfydabqed`:
> ```sql
> -- the bug: 0 hits
> select count(*) from catalog_items where available_for_sale
>   and (title ilike '%rx bar%' or brand ilike '%rx bar%' or variant_title ilike '%rx bar%');
> -- the fix: RXBAR Protein Bar, score 6
> select brand, title, 2*(select count(*) from unnest(array['rx','bar']) t where coalesce(brand,'') ilike '%'||t||'%')
>   + (select count(*) from unnest(array['rx','bar']) t where coalesce(title,'') ilike '%'||t||'%') s
> from catalog_items where available_for_sale order by s desc limit 3;
> -- why tier 3 isn't the big bug: 2 rows in prod (28 in dev)
> select count(*) from nutrition_products;
> ```

**Date:** 2026-07-16
**Scope:** The three food search/barcode surfaces (food logging, add/swap food, carb loading), their data-source cascades, `user_foods`, the meals tables, and endurance-vs-carb-loading classification.
**Method:** Three parallel code investigations + live verification on a booted iOS simulator (dev flavor, iPhone 17 Pro).
**Companion doc:** [`food-formula-plan-architecture-audit.md`](./food-formula-plan-architecture-audit.md) (2026-07-03) — covers the plan/formula layer. Its §3 and P1-item-6 predicted the classification gaps confirmed here.

---

> ## ⚠️ CORRECTIONS — 2026-07-16 (after reconciling with the agent food-DB sweep + Notion Bug Reports)
>
> Two claims in the original draft of this doc were **wrong**. Both are corrected in place below; recorded here so the error is visible.
>
> **1. "Tier 3 fetched-and-discarded is the largest bug" — WRONG ON PROD.**
> Verified by direct query 2026-07-16: `nutrition_products` holds **2 rows in prod** (both USDA) and **28 in dev** (11 USDA / 17 OFF). The `cheerios` simulator repro passed **on dev's 28 rows**. The render fix is a real defect and still worth fixing, but on prod it unlocks a **two-row table**. **The largest bug is tokenization** (Notion `39ee3fdb`) — see §7.
>
> **2. "`UnifiedMealSearchResults` is a thin wrapper — delete it" — WRONG.**
> It *is* a wrapper (it calls `UnifiedFoodSearchResults:152`), but it is **not redundant**: it adds the meal-logging **quick-match strip** (favorites, recents, recipes, `kCommonIngredients`) plus `_QuickMatchCard` / `_FoodResultTile` / `_CatalogResultTile` and a `catalogItemBuilder` override. Deleting it would delete real features. **The correct fix is to forward one parameter** (`onNutritionProductResultTap`), not delete 303 lines.

## 0a. DECISION LOG (2026-07-16) — read this first

| # | Decision | By | Where |
|---|---|---|---|
| 1 | ❌ **No ~1.9M-row USDA backfill.** Voids `39ee3fdb`'s "tokenize before backfill" premise; makes the **live USDA tier required**; drops `search-nutrition-products` tokenization to low priority (2-row table). | Lee | §9b |
| 2 | ❌ **No pgvector.** Measured, not asserted: FTS→**0**, trgm@0.4→**681/3469**, scored lexical→**7/7**. `rx bar`→`RXBAR` is lexical, not semantic. Embedding p90 ≈500ms > 300ms debounce. Corpus is 4,511 + a 2-row cache. Re-affirms the 2026-07-02 call. | Claude, Lee asked | §9c |
| 3 | ✅ **Scored lexical RPC**: `2×brand + 1×title` token hits, threshold ≥2, ORDER BY score. **7/7 on the sweep's recoverable list**, 37ms unindexed. | Claude | §9c |
| 4 | ✅ **Do not match `variant_title`** (still display it). Kills flavour false-positives (`banana bread` 5→**0**). The variant ticket flagged this as "a product call, not filed" — **this is that call.** | Claude | §9c |
| 5 | ✅ **APPROVED: migrate OFF → Search-a-licious.** ≈3× reliability (10/10 @1s vs 5/10 @1/3s), full `nutriments` in one call, Lucene, `_score`. **It is Open Food Facts' OWN project** (their official replacement for `cgi/search.pl`, hosted at `search.openfoodfacts.org`, indexing the same OFF DB) — **not a new source, just a better door to the same corpus. ODbL applies identically; the `resale_ok` firewall is unchanged.** | **Lee, 2026-07-16** | §9c |
| 5b | ❌ **No legacy-OFF fallback.** Follows from 5: same corpus → zero extra coverage, and it falls back to the *less* reliable endpoint (5/10 vs 10/10). | Lee asked, Claude | §9c |
| 6 | ✅ **USDA ∥ OFF in parallel, merged** — genuinely different corpora, empirically complementary. Mirrors `lookup-product`'s barcode pattern. | Claude | §9c |
| 7 | ✅ **Cascade confirmed already correct**: local → catalog → cache → [USDA ∥ OFF]. External never fires before local+our-DB are exhausted. | verified in code | §9c |
| 8 | ✅ **Keep `swap_food` recommendations as-is** (product_type ∩ category). Beware the decoy duplicate `getRecommendations()`. | Lee | §6c |
| 9 | ✅ **Delete `carb_loading_user_foods`** — never synced (live data loss), ~955 lines. Fold into `user_foods` + `meal_types`. Keep `carb_loading_foods`. | Claude, Lee asked | §5b |
| 10 | ✅ **Don't build a `meals` table** — `meal_logs` + `saved_meals` exist and sync. | Claude | §4 |

**Claims I got wrong and corrected (kept visible on purpose):**
1. *"Tier 3 discard is the largest bug"* — **wrong on prod** (2 rows there; my `cheerios` repro ran on dev's 28). Real #1 is catalog matching.
2. *"`UnifiedMealSearchResults` is a thin wrapper, delete it"* — **wrong**; it owns the quick-match strip. Fix = forward one param.
3. *"OFF `cgi/search.pl` is dead"* — **wrong**, from one curl missing the `User-Agent` + `action=process`. **It works** (verified in the dev app). It's *flaky*, and the real bug is that we swallow the failure silently.

## 0. Bottom line up front

- **The cascade is sound; the render layer drops it.** All three surfaces share one `FoodSearchController` that correctly *fetches* every tier. Two of three **discard tier 3 before rendering**. This is the single largest bug — see §7.
- **Text search never reaches live USDA or live Open Food Facts on any surface.** `search-nutrition-products` is a pure cache read. Live USDA exists *only* in the barcode path.
- **There is no local copy of TheFeed catalog.** Catalog search is network-only and dead offline.
- **The meals tables already exist** (`meal_logs` + `saved_meals`, Drift *and* Supabase, both synced). The gap is that `items` is a JSON blob with no join to `user_foods`.
- **`user_foods` is not the spine it should be.** Only add/swap writes to it. Logging writes nothing; carb loading writes a parallel table.
- **Carb loading has two disconnected food lists that disagree with each other**, and its search applies no carb-appropriateness filter at all.

---

## 1. The shared foundation

**There are five search surfaces, not three** (all use the same keyed controller `lib/shared/controllers/food_search_controller.dart`):

| Surface | File | Filter |
|---|---|---|
| Food logging | `meal_logging/.../log_meal_screen.dart` | `generalFirst` |
| Build a meal | `meal_logging/.../build_meal_screen.dart` | `generalFirst` |
| Add/Swap food | `nutrition_plan/.../swap_food_screen.dart` | `fuelOnly` / `all` |
| Carb loading | `carb_loading/.../carb_loading_food_selection_screen.dart` | **none → `all`** |
| Food preferences | `settings/.../food_preferences_screen.dart` | `fuelOnly` |

Service layer: `SharedFoodSearchService` (`shared/services/food_management/shared_food_search_service.dart`) — consumed only by the controller. Not a duplicate path.

### Text-search cascade

**Target (requirement, Lee 2026-07-16):** local cache → product catalog → Supabase cache → **live USDA/FDA** → Open Food Facts, on **all three surfaces**.

**Actual (as built):**

| # | Tier | Implementation | Status |
|---|---|---|---|
| 1 | Local in-memory pool (user foods + template foods) | `updateSearch()` — `food_search_controller.dart:231-262` | ✅ all 3 surfaces |
| 2 | TheFeed catalog | debounced 300ms → `_searchCatalog()` (`:326-362`) → `CatalogSearchService.searchCatalog` (`catalog_search_service.dart:143-158`) → **`search-catalog`** edge fn → `catalog_items` MV | ✅ all 3 surfaces |
| 3 | Supabase `nutrition_products` cache | **only if `local + catalog < 5`** (`_kFewLocalResultsThreshold = 5`, defined `:17`; gate at `:373`) → **`search-nutrition-products`** | ⚠️ fetched on all 3, **rendered only on add/swap** — see §7 |
| — | **live USDA / FDA** | **DOES NOT EXIST on text search** — see "The USDA illusion" below | ❌ **missing tier** |
| 4 | Direct Open Food Facts | **manual only** — `searchOpenFoodFacts()` (`:274-301`) → `world.openfoodfacts.org/cgi/search.pl` | ⚠️ logging: no-op; add/swap: hidden; carb loading: yes |

> **The FDA/USDA tier is required but absent.** Lee's stated requirement is that the FDA database (USDA FoodData Central) be a real tier here, on all three surfaces. Today it is a tier *in name only*: text search sees USDA data **only** where a past barcode scan happened to cache it into `nutrition_products`. Live USDA exists solely in the barcode path (`lookup-product`). This is tracked as §9 P2-item-5 and is **not** addressed by the §7 render-layer fix.

### Barcode cascade (`supabase/functions/lookup-product/index.ts`)

| Priority | Source | Line |
|---|---|---|
| P0 | `catalog_products` + `catalog_variants` by barcode | `:610-613`, `:187` |
| P0.5 | `nutrition_products` cache (bumps `hit_count`) | `:632-637`, `:481-528` |
| P1 | **live USDA FDC + live OFF in parallel**; USDA preferred for nutrition, OFF borrowed for the image; write-through cache | `:657-668`, `:670-672`, `:679` |
| P1-fb | OFF fallback on USDA miss | `:688-691` |
| P2 | OFF-by-id when no barcode | `:696` |

**Barcode ≠ text search.** Barcode is the richer cascade and the only live-USDA path.

### The USDA illusion

`search-nutrition-products/index.ts:58-63` is a single `.from('nutrition_products').select().or(ilike...)`. There is **no `api.nal.usda.gov` call in it**. USDA rows appear there only if an *earlier barcode scan* wrote them through via `cacheNutritionProduct` (`lookup-product/index.ts:542`). So the "USDA tier" on text search is really *"a cache of things somebody already scanned."*

> **`nutrition_products` has no DDL in this repo.** It exists in Supabase but appears in no migration and neither `docs/dev_schema.txt` nor `docs/prod_schema.txt`.

---

## 2. Surface-by-surface comparison

| | (A) Food Logging | (B) Add/Swap | (C) Carb Loading |
|---|---|---|---|
| **Entry** | `log_meal_screen.dart:726` | `swap_food_screen.dart:794` (`/swap-food`) | `carb_loading_food_selection_screen.dart:592` |
| **Filter** | `generalFirst` (`:449`) | `fuelOnly` if `during_run`, else `all` (`:115-120`) | **never calls `setFilter`** → default `all` |
| TheFeed catalog | YES | YES | YES |
| Supabase cache | **NO — fetched, never rendered** | YES (`:891-893`) | **NO — fetched, never rendered** |
| Local Drift pool | YES (`:429-437`) | YES (`swap_food_controller.dart:198,248-257`) | YES (`controller:145-183`) |
| USDA — text | **NO** | **NO** (cached rows only) | **NO** |
| USDA — barcode | YES | YES | YES *(but result unusable — see §5)* |
| OFF — text | **NO** — button off (`:772`), handler no-op (`:771`) | reachable, button hidden (`:890`) | **YES** |
| OFF — barcode | YES | YES | YES |
| Barcode scanning | YES (`:525`) | YES (`:247`) | YES (`:113`) |
| **`user_foods` READ** | YES (`:433`) | YES | YES (`controller:181-183`) |
| **`user_foods` WRITE** | **NO** | YES (`:223,278,454,675`) | **NO** → `carb_loading_user_foods` |
| Recommendations | NO | YES (`:970`) — local template foods only | **NO** |
| Timing prompt | slot in `LogScannedFoodScreen` | **NO** — caller-supplied `category:33` | meal type is a route param |
| Sport-aware labels | n/a | **NO** — hardcoded `*_run` | n/a |

There is **no "Discover" tab**. Tabs are Recent / Common / Recipes / Describe / Manual. `"discover"` survives only as an analytics string (`log_meal_screen.dart:530`).

---

## 3. `user_foods` — read by all, written by one

**Drift:** `lib/shared/database/tables/user_foods_table.dart` (unique `(device_id, client_food_id)`).
**Supabase:** `docs/dev_schema.txt:954`.
**Sync:** `needs_upload` + `local_updated_at`, registered in `sync_coordinator.dart:289`.

### Four parallel write paths (architectural debt)

| Path | File | Problem |
|---|---|---|
| `UserFoodsRepository` | `features/user_foods/data/user_foods_repository.dart` | The *intended* path — dirty-flag + `uploadDirtyRecords`. Only 4 callers. |
| `UserFoodCrudService` | `shared/services/food_management/user_food_crud_service.dart:28` | **Bypasses the repository** — does its own background Supabase uploads (`:284,335,352`) |
| `FoodsDao` | `shared/database/daos/foods_dao.dart` | Raw table access, no sync semantics |
| `user_repository` | `features/auth/.../user_repository.dart:579-587` | A *fourth* `syncUserFoodsFromSupabase` → `replaceUserFoods` |

The `user_foods` "feature" is a single file with no domain/application/presentation layers — it is only a sync repository. All actual CRUD lives elsewhere.

### Schema divergence

Drift column is `product_type_id`; Postgres column is `product_type` (enum). Bridged at `user_foods_repository.dart:115` (upload) and `:318` (download).

---

## 4. Meals — already built

**There is no `meals`/`logged_meals`/`meal_items` table, and none is needed.**

| Table | Drift | Supabase | Purpose |
|---|---|---|---|
| `meal_logs` | `meal_logs_table.dart` | `dev_schema.txt:2329` | A logged meal |
| `saved_meals` | `saved_meals_table.dart` | `dev_schema.txt:2374` | Explicit favorites ("My Meals") |

Both are `SyncableRepository` with `needs_upload`. `Build a Meal → "Start from a saved meal / recent"` is live in the UI.

- **The real gap:** meal components are a JSON array in `items` (`{name, portion, calories, carb_g, ...}`), with **no join to `user_foods` or `catalog_*`**. Macro corrections and "similar foods" cannot propagate into logged meals.
- **Divergence (upload risk):** Drift made `slot` **nullable** at schema v14 (`meal_logs_table.dart:26`, migration `app_database.dart:384-391`); Postgres still has `slot text NOT NULL` + CHECK. A null-slot log will fail upload.

---

## 5. Carb loading

### Two disconnected, disagreeing food lists

| | `carb_loading_foods` (DB) | `CarbFoodsList` (hardcoded) |
|---|---|---|
| Where | Drift `carb_loading_foods_table.dart` + Supabase; seeded `_archived/20251008000001_seed_carb_loading_foods.sql` | `features/carb_loading/domain/carb_foods_list.dart:7-115` |
| Count | 27 foods | 18 foods (from Featherstone Nutrition `carb_load_guide.pdf`) |
| Carbs | **real per-serving values** (14–72g) | **every food exactly 50g** |
| Taxonomy | `meal_types[]` | `grains, snacks, fruits, liquids` (unrelated) |

They disagree (banana 27g vs 25g; sports drink 16g/cup vs "2 scoops Skratch = 50g") and share **no name keys** (`banana` vs `bananas`), so `getFoodByName` silently returns null on DB-sourced rows. `CarbFoodsList` also holds the target math (8g/kg).

### No carb-load classification exists

`catalog_products` has **no** carb-load flag. `categories` is strictly the run-phase taxonomy: `before_run`, `during_run`, `after_run`, `transition`. The carb loading screen never calls `setFilter`, so its search is fully unfiltered.

### Bugs

- **Barcode scan is unusable.** `_onBarcodeScan` → `_selectFood(rawFood)` (`:125`) → `addFoodToMeal` hits the `selectedFood is Food` branch (`controller:439`) → `importFromFoodsTable(sourceFoodId:)` (`:466-471`) → looks up a scanned id in `foodsTable` → `throw ArgumentError('Source food not found')` (`food_import_service.dart:33-36`). The correct helper `createFromBarcodeScan` (`:98`) is only reachable from the OFF path.
- **Hardcoded macros.** `addFromOpenFoodFacts` passes `carbsPerServing: 30.0, // Default - user can edit later` (`controller:603`) — on the one screen where carbs are the whole point.

---

## 6. Endurance-vs-general classification

The field is **`product_type` / `product_type_id`**. **There is no `is_fuel` column anywhere** — `is_fuel` is a client-side derived predicate:

`shared/services/food_management/fuel_predicate.dart:10-26` — `kFuelProductTypeCodes` = `gel, chew, drink_mix, bar, waffle, sports_drink, electrolyte_only, electrolytes_fluids, hydration_with_carbs, quick_carbs, solid_carb_snacks, real_food_carbs, recovery_shake, protein_recovery, capsule`. Everything else (notably `real_food`, `import`, null) is general. Legacy UUIDs normalize via `product_type_mapper.dart:4-21`.

`enum FoodSearchFilter { all, fuelOnly, generalFirst }` (`food_search_controller.dart:24-33`), applied by `_applyLocalFilter` (`:147`), `_applyCatalogFilter` (`:166` — keeps `productTypeId == null` because The Feed is curated), `_applyNutritionProductFilter` (`:195` — drops unclassified, since USDA/OFF is general).

### Classifier mismatches

`.claude/commands/refresh-feed.md` → `scripts/classify_unclassified_by_type.sql` (deterministic SQL, no LLM; only touches `classification_source IS NULL`, never overwrites `'claude'`).

- It emits **`'supplement'`**, which is **not** in `kFuelProductTypeCodes` and **not** in `product_type_mapper` → supplements classify as general food.
- Snacks/Breakfast → `real_food` → also non-fuel → hidden from `fuelOnly` surfaces once classified (visible only while `product_type_id` is null, per the catalog null-keep rule).

### Sport-awareness is a data problem, not a label problem

`ActivityType.getSectionTitle()` (`shared/domain/activity_type.dart:169-195`) *does* return "During Ride"/"During Swim". It is never called from the swap flow, and both plan surfaces deliberately override it back to bare BEFORE/DURING/AFTER (`activity_detail_screen.dart:810-814`, `nutrition_sections_builder.dart:196`). Critically, `nutrition_sections_builder.dart:175-181` **hardcodes `category = 'during_run'` regardless of sport, by design** ("The plan data … always stores 'during_run' … regardless of sport type").

**Implication:** correct swim/bike/run wording requires carrying sport through the plan data first. A string swap alone cannot fix it.

---

## 7. Tier 3 is fetched and thrown away — real, but NOT the largest bug (corrected)

> **Header corrected 2026-07-16.** This section originally called this "the largest bug". **It isn't.** `nutrition_products` holds **2 rows in prod** — the `cheerios` repro below passed on **dev's 28 rows**. It's a genuine defect and cheap to fix, but its prod impact is ~nil until the live USDA/OFF tier lands (which is what makes it worth doing — see §10 Phase 2). **The actual largest bug is catalog matching — §9c.**

**Verified live on the simulator, same query, two screens:**

| Screen | Query | Result |
|---|---|---|
| Food logging | `cheerios` | **"No foods found for 'cheerios'"** |
| Add/Swap | `cheerios` | **"Cheerios Apple Cinnamon Cheerios Cereal — 30g carbs"** |

**Root cause — the bug IS a DRY defect.** `UnifiedMealSearchResults` (303 lines, `meal_logging/presentation/widgets/`) is **not a separate implementation — it is a thin wrapper around `UnifiedFoodSearchResults`** (537 lines, `shared/widgets/food_search/`, used by the other four surfaces). The wrapper never forwards `onNutritionProductResultTap` (`unified_meal_search_results.dart:152-176` — the param is simply absent), and the shared widget hides the entire "More Results" block when that callback is null (`unified_food_search_results.dart:266-267`).

**Therefore: deleting the wrapper fixes the bug.** This is a case where the DRY cleanup and the bug fix are the same edit. Only `log_meal_screen` and `build_meal_screen` use the wrapper.

**Compounded on food logging:** `showOpenFoodFactsButton: false` (`log_meal_screen.dart:772`) and `onSearchOpenFoodFacts: () {}` is a **literal no-op** (`:771`). The comment at `:769-770` claims "auto USDA/OFF already covers this" — **it does not**. Same for `build_meal_screen.dart:923-924`.

**Net effect:** the controller pays for the `nutrition_products` fetch on A and C, then discards it. On A, with OFF also wired to a no-op, a query with no local/catalog hit returns **nothing at all** despite three data sources being available and one of them holding the answer.

**Why this is #1:** it is the highest user-visible impact (search silently lies about having no data), it is contained to the render layer, the cascade beneath it already works, and it requires no schema change, no migration, and no edge-function deploy.

### Related but separate

`build_meal_screen.dart:755` passes `context: 'build_meal_add_food'` rather than `'meal_log_discover'`, so a barcode scan inside the general meal builder routes through the run-phase category picker (`barcode_scanner_screen.dart:299-321`) — wrong for a general meal.

---

## 8. UI/UX findings (simulator, dev flavor)

- **Retail packaging leaks into nutrition.** "Salted Caramel (with Caffeine) / Pack of 8" logs as **1 serving / 100 kcal**. You buy a pack of 8; you eat one gel. Rows also omit the brand — six near-identical GU flavors render with no "GU" anywhere.
- **Name duplication.** "Cheerios Apple Cinnamon **Cheerios** Cereal" — brand concatenated onto a name that already contains it.
- **Carb loading protocol screen never shows the active protocol.** Selecting 3-Day fires a toast and pops back to Event Details; re-entering "Edit Carb Loading Plan" shows the identical chooser with no selected state, and never reaches food selection. Title truncates to "Choose Carb Loading Pr…".
- **Tab bar lies.** Search results render beneath a still-highlighted "Recent" chip.
- **Dev-only:** the two debug FABs overlap the "Log it" and "Edit Carb Loading Plan" CTAs.
- **Unconfirmed, worth a look:** dashboard BURNED jumped 1,701 → 2,280 kcal immediately after logging a 100 kcal gel. Not chased; no causal claim.

---

## 8b. Dead code inventory (verified 2026-07-16)

| Item | Size | Evidence |
|---|---|---|
| **`supabase/functions_old/`** | **18 files, 7,620 lines** | Stale copies of `lookup-product`, `get-foods`, `barcode-lookup`, `carb-loading`, `generate-ai-nutrition-plan`, etc. Referenced by no yaml/json/md config. |
| **`UnifiedMealSearchResults`** | 303 lines | A wrapper around `UnifiedFoodSearchResults` that drops a param. Delete → §7 bug fixed. |
| **`CarbFoodsList`** | ~110 lines | `carb_foods_list.dart:7-115`. Only 2 consumers (`carb_loading_meal_section.dart:137`, `carb_loading_food_pills.dart:71`). Duplicates + contradicts the seeded `carb_loading_foods` table. Holds the 8g/kg target math — **extract that before deleting.** |
| `search-catalog` + `search-nutrition-products` | 132 + 83 lines | Become dead once merged into `search-foods` (§9 P2-5). |
| No-op OFF handler | 2 lines | `log_meal_screen.dart:771-772`, `build_meal_screen.dart:923-924`. |
| `"discover"` analytics string | 1 line | `log_meal_screen.dart:530` — names a tab that does not exist. |

**Not dead (checked, keep):** `SharedFoodSearchService` (the controller's service layer); `client_food_pool_service.getFoodsForPhase` (live, client-side — the *edge* copies were already removed 2026-07-03 per `_shared/nutrition/food-queries.ts:4`).

---

## 9. Prioritized recommendations — ⚠️ SUPERSEDED by §10

> **This was the first-pass list, written before the sweep reconciliation, the pgvector testing, and Lee's no-backfill call. It is kept for history only — several items are now known wrong (esp. P0-1 "delete the wrapper" and P2-5's framing).** **Use §10 (MERGED ROADMAP) as the plan of record.**

**P0 — one fix, largest win:**
1. **Render tier 3 on food logging and carb loading.** Forward `onNutritionProductResultTap`; replace the no-op OFF handler. No schema/migration/deploy.

**P1 — correctness:**
2. **Fix the carb loading barcode crash** (route to `createFromBarcodeScan`).
3. **Stop hardcoding `carbsPerServing: 30.0`** in `addFromOpenFoodFacts`.
4. **Reconcile `meal_logs.slot`** nullability (Drift v14 vs PG `NOT NULL`) before it breaks uploads.

**P2 — make the sources real:**
5. **Add a live USDA/FDA text-search tier** with write-through to `nutrition_products`, mirroring what `lookup-product` already does for barcodes. **Confirmed requirement (Lee, 2026-07-16), not optional** — the FDA database must be a real tier in the text-search cascade on all three surfaces. This is what actually makes "full capacity on all three pages" true; the P0 render fix does not deliver it.
6. **Add DDL for `nutrition_products`** so it exists in the repo.
7. Consider a **local catalog cache** (catalog search is currently dead offline).

**P3 — structural:**
8. **Unify on `user_foods` as the spine.** Logging and carb loading write through it; collapse the four write paths onto `UserFoodsRepository`; make `carb_loading_user_foods` a facet (flag/join), not a parallel table.
9. **Delete `CarbFoodsList`**; keep the seeded table, fix name keys, surface those foods as the carb loading recommendation rail.
10. **Join `meal_logs.items` to `user_foods`** instead of storing an inert JSON blob.
11. **Carry sport through plan data**, then derive labels via `getSectionTitle()`. Own piece of work.
12. Add `'supplement'` to the fuel predicate/mapper, or decide it's intentionally general.

**Do NOT build:** a `meals` table (`meal_logs` + `saved_meals` already exist and sync).

---

## 9b. In-flight work from the agent food-DB sweep (Notion "Bug Reports", 2026-07-15)

Canonical evidence: `data/food-db-test/RESULTS-2026-07-15.md`, sweep `scripts/food-db-test/sweep.py`, raw `data/food-db-test/sweep-2026-07-15.csv`, handoff `docs/handoffs/2026-07-15-food-db-coverage.md` — **ops commit `7da418e`; NOT present on `develop`.**

**Sweep headline (prod, 117 terms):** only **47.9%** find the food. Branded grocery **9.5%**. Whole foods **88.9%** (canonical; an earlier 81.8%/62.2% figure is retired). **9 of 72 misses are products already in the catalog** — fixing tokenization lifts feed coverage **40% → ~63% with no new data.**

| Notion | Title | Status | Branch |
|---|---|---|---|
| [`39ee3fdb`](https://app.notion.com/p/39ee3fdb754c81a58790f75b7ced0c2b) | Multi-word searches return 0 — **edge fns** match whole query as one substring | **Recommend: Manual Fix** | **none — this is ours** |
| [`39fe3fdb…a8ef`](https://app.notion.com/p/39fe3fdb754c8116a8efd94957a22440) | Multi-word misses ingredients/recipes/favourites — **client** filter | **Fix Ready** | `claude/fix-39fe3fdb-multi-word-search-filter` |
| [`39fe3fdb…86ed`](https://app.notion.com/p/39fe3fdb754c81d886eded33cbfebab2) | Results show the **flavour, not the product** — 'oreo' → Clif bar "Oreo / Box of 12" | **Fix Ready** | `claude/fix-39fe3fdb-food-search-variant-title` |

**The tokenization defect is 4 layers, not 1:**
| Layer | Tokenizes? |
|---|---|
| `template_foods` — `FoodSearchController._matchesSearchTokens` | ✅ the reference behavior |
| `kCommonIngredients` / recipes / favourites — `unified_meal_search_results.dart:93` | ❌ → fixed by the multi-word branch |
| `search-catalog/index.ts:52,69` — `%${trimmedQuery}%` | ❌ **open** |
| `search-nutrition-products/index.ts:42,61` — same | ❌ **open** |

Prod evidence: `rx bar` → **0** / `rxbar` → **13**; `nuun electrolyte tablets` → 0 / `nuun` → 20; `coca cola` → 0 / `coca-cola` → 1; `pringles original` → **0** against a row literally named "Pringles Crisps Original 5.2oz".

**`39fe3fdb…86ed` is the same defect this audit hit on the simulator** ("Salted Caramel (with Caffeine) / Pack of 8" — no brand, no product name). Cause: `result.variantTitle ?? result.title` at 4 sites. `CatalogSearchResult.displayName` (`catalog_search_service.dart:116-121`) **already returns the correct `'$title — $variantTitle'`** and the other surfaces (CatalogCard → swap/prefs/carb loading) already use it. **This is the one defect that produces silently wrong data** — a miss is visible, a wrong log is not.

> ⚠️ **The two Fix Ready branches conflict with each other** — both edit `unified_meal_search_results.dart`. Land one, rebase the other.

### 🔴 THE USDA BACKFILL — ❌ REJECTED (Lee, 2026-07-16)

`39ee3fdb` assumed a **~1.9M-row USDA backfill into `nutrition_products`** was the plan, and argued tokenization was a hard prerequisite for it.

> **DECISION (Lee, 2026-07-16): we are NOT doing the 1.9M-row backfill.**

**Consequences — this rewrites parts of `39ee3fdb`'s reasoning:**

1. **The "tokenize before backfill" sequencing constraint is void.** There is no backfill to sequence against. Tokenization is still done first, but on its own merit (biggest coverage win, no new data), not as a prerequisite.
2. **The live USDA text tier is now REQUIRED, not optional** — with no backfill, a live call is the *only* way FDA data ever reaches text search. This restores §9 P2-5 as the plan of record.
3. **Tokenizing `search-nutrition-products` drops to LOW priority.** That table stays a **cache** (2 rows prod / 28 dev), grown incrementally by barcode scans and by write-through from the new live-USDA tier. With live USDA, **USDA's own `/foods/search` API does the matching** — our `ilike` only ever reads the small local cache. `39ee3fdb` bundled both edge functions on the assumption of 1.9M rows; without it, **essentially all the tokenization value is in `search-catalog`** (704 Feed products, 40% → ~63% coverage).
4. `39ee3fdb`'s `coca cola`/`pringles original` evidence remains factually true, but it argued for backfill-readiness. Still worth fixing — just not urgent.

---

## 9c. SEARCH STRATEGY — decided 2026-07-16 (empirically, against prod)

### ❌ pgvector — REJECTED. Measured, not asserted.

Tested against **prod `catalog_items` (4,511 rows / 3,469 sellable — NOT 704; that's products before variants)**:

| Approach | `rx bar` result | Verdict |
|---|---|---|
| Current whole-phrase `ilike` | **0** | the bug |
| Tokenized **AND** (the Notion fix plan) | **13** ✓ but `nuun electrolyte tablets` → **0**, `clif shot bloks` → **0** | **insufficient — fails its own regression tests** |
| **FTS** `websearch_to_tsquery` | **0** | **categorically cannot work** |
| Trigram `word_similarity > 0.4` | **681 of 3,469** | unusable precision |
| **Scored lexical (chosen)** | **RXBAR #1, score 6 vs next 3** | ✓ **7/7 on the recoverable list** |

**Why FTS structurally fails:** Postgres's parser never splits a solid ASCII token. `RXBAR` indexes as the single lexeme `rxbar`; `rx bar` parses to `'rx' & 'bar'`. Those can never `@@`-match. No stemmer or dictionary splits compounds (only Ispell/Hunspell for German/Norwegian). A synonym dictionary is one-token-in/one-token-out and can't do phrases. Confirmed against the official parser/dictionary docs **and** measured live (0 hits).

**Why pgvector is the wrong tool:**
1. `rx bar` → `RXBAR` is a **lexical substring** problem. Whether an embedding bridges it depends on the model's BPE tokenizer — replacing a deterministic SQL bug with a probabilistic black box.
2. It would make **precision worse**. `banana bread` → "Send Bar" is a *legitimate* lexical match (the flavour name contains those words). Embeddings cluster by theme, so they'd *also* pull "oatmeal cookie"/"cinnamon roll" bars with **zero** word overlap.
3. **Latency disqualifies it**: query-embedding p90 ≈ **500ms** (p99 seconds) — the network hop alone exceeds our entire 300ms debounce budget, before Postgres runs.
4. **No corpus.** pgvector's own README: seq scan beats ANN below ~tens of thousands of rows. We have 4.5k and a **2-row** cache with **no bulk seed** (rejected).
5. **Already decided 2026-07-02**: *"pgvector NOT needed (trgm+FTS)"*.
6. **We don't need the speed**: the scored scan runs in **37ms** over all 3,469 rows, unindexed. Trigram GIN indexes already exist on every relevant column.

> Revisit only if a large, unstructured corpus ever lands. The no-backfill decision means that isn't coming.

### ✅ The chosen design — scored lexical RPC

**Score = 2 × (brand token hits) + 1 × (title token hits)**, threshold ≥2, ORDER BY score DESC. Validated on the sweep's **entire** "recoverable misses" list — **7/7 correct top hit**:

| Query | Top result | Score |
|---|---|---|
| `science in sport beta fuel` | SiS Beta Fuel Drink Mix | 9 |
| `precision hydration 1500` | Precision Fuel and Hydration Tablets PH 1500 | 7 |
| `honey stinger chews` | Honey Stinger Energy Chews | 7 |
| `rx bar` | RXBAR Protein Bar | 6 |
| `sis go isotonic gel` | SiS GO Isotonic Energy Gels | 4 |
| `untapped maple gel` | UnTapped Energy Gel | 4 |
| `huma gel` | Huma Chia Energy Gel | 4 |

**Three deliberate design calls:**
1. **Do NOT match `variant_title`** (still *display* it). This is what kills the flavour false-positives — `banana bread` goes from 5 bogus hits to **0**. Same root cause as the "oreo → Clif bar" ticket, from the other side. The ticket flagged this as *"a product call, not filed"* — **this is that call.**
2. **Must be an RPC, not PostgREST.** Supabase maintainers confirm `ts_rank` ordering is unsupported, and `.or()` ORs whole per-column predicates — it cannot express "this word appears in any column." **The Notion fix plan ("chain `.or()` calls") produces exactly the strict AND that fails.**
3. **Fix the ranking.** `search-catalog:71` orders by `nutrition_confidence` — **data quality, not relevance**. Even matched products come back arbitrarily ordered.

### External APIs — researched + live-tested 2026-07-16

**Open Food Facts `cgi/search.pl` — ⚠️ FLAKY, NOT DEAD. (Corrected 2026-07-16 — an earlier draft of this doc wrongly called it dead.)**

> **How the error happened:** the first curl omitted the `User-Agent` header and `action=process&search_simple=1`, got a 503, and that single data point was written up as "dead". **Verified in the dev app: it works.** Tapping "Search Open Food Facts" for `pringles` on Food Preferences returned real OFF results (Pringles Original, Sour Cream & Onion, Paprika). Replicating the app's *exact* request by curl → **HTTP 200**, `count=17010`.

What is actually true:
- **It is intermittent.** 10 app-shaped requests at 1-per-3s (≈20/min, over OFF's documented 10/min): **5 × HTTP 200, 5 × 503/timeout**. In the dev app the **first tap returned nothing and the second returned results** — same query, seconds apart.
- **Failures are silent.** `searchOpenFoodFacts` (`food_search_controller.dart:287-297`) catches, logs a warning, and sets `isSearchingOpenFoodFacts: false` with **no results and no error UI** → the user sees "No foods found for X", which is **indistinguishable from a genuine miss**. This is the real defect, and it's ours, not OFF's.
- **No language filter.** Results came back French/Dutch ("Légumes", "Tuiles de pommes de terre", "Aardappelchips") — OFF's `lc`/`countries` params aren't passed.

### Search-a-licious — what it is, measured 2026-07-16

OFF's new Elasticsearch-backed search service (`search.openfoodfacts.org/search`), replacing the Perl `cgi/search.pl`. OpenAPI self-reports `version: 0.1.0` ("beta"). Endpoints: `/search`, `/autocomplete`, `/document/{id}`, `/health`.

| | Legacy `cgi/search.pl` | **Search-a-licious** |
|---|---|---|
| **Reliability (measured)** | **5/10 OK** @ 1 req/3s | **10/10 OK** @ 1 req/**1s** |
| Nutrition in search response | no | **yes — full `nutriments`, ONE call** |
| Relevance score | no | **`_score`** (ES-native, default sort) |
| Query syntax | keyword only | **Lucene** — verified `brands:pringles` → 1,040 hits, all Pringles |
| Autocomplete | no | **`/autocomplete`** (`fuzziness` param) |
| Field allowlist | no | **`fields=`** (smaller payloads) |
| Facets / sort | no | `facets`, `sort_by` |
| Rate limit | 10/min search | **undocumented** — self-throttle |

**≈3× the request rate with zero failures.** That is the real win — reliability, not coverage.

⚠️ **Caveats:** complex boolean queries can 500 — `product_name:"energy gel" AND brands:gu` returned non-JSON; **validate every query shape before shipping and wrap in a try/catch**. `langs=en` did **not** filter our test results (same products returned) — the French/Dutch problem needs `countries_tags` or client-side filtering; `countries_tags:en:united-states AND pringles` returned **0**, so the syntax needs work. Beta software: treat as best-effort.

### ❌ "Fall back to legacy OFF if Search-a-licious lacks coverage" — REJECTED, and here's why

**They are the SAME database.** Search-a-licious is an ES index *over Open Food Facts* — the identical corpus the legacy CGI queries. Measured: `pringles` → legacy 1,362 vs s-a-l 1,094 — a **matching-semantics** difference, not a data difference.

So a legacy fallback:
- **Adds zero coverage** — same products.
- **Falls back to the *less* reliable endpoint** (5/10 vs 10/10). When s-a-l is down, legacy is likelier down too.

**The fallback that DOES add coverage is USDA ↔ OFF — genuinely different corpora, and empirically complementary (neither wins):**

| Query | USDA | OFF (s-a-l) |
|---|---|---|
| `walnuts` | **WALNUTS** ✓ | "Walnusskerne" (German) ✗ |
| `vitamin water` | "Milk, chocolate, lowfat, with added vitamin A" ✗ | **Vitamin water** ✓ |
| `clif bloks` | "Clif Z bar" ✗ | **Clif Blok Sour Apple** ✓ |
| `pringles original` | PRINGLES, POTATO CRISPS, ORIGINAL ✓ | Pringles original ✓ |

**Design: query USDA and OFF in PARALLEL and merge under our own scorer — not a strict fallback.** USDA wins generic/US whole foods; OFF wins branded/international. This mirrors what `lookup-product` already does for barcodes (`Promise.all([lookupUsda, fetchOffProduct])`, Lee's 2026-07-01 call) — same pattern, same reason. Keep the ODbL firewall: `resale_ok` already excludes OFF rows.

**USDA FDC** — live-tested:
- **`/foods/search` DOES return `foodNutrients`** (65/11/16 nutrients on our test queries) → **one call is enough for list display**; only call `/food/{fdcId}` for `labelNutrients` on tap. Halves our call budget.
- **Rate limit 1,000/hr — PER IP.** ⚠️ **Memory said 3,600/hr — that appears WRONG.** An edge function proxies every user behind **one IP**, so this is a real ceiling. Mitigations: the existing thin-results gate, write-through caching, and requesting an elevated limit from FDC.
- Documented Lucene-ish syntax: `"phrase"`, `+require`, `-exclude`, `*`, `()`, `field:value`. `requireAllWords` works but is **absent from the OpenAPI spec** — prefer documented `+term`.
- **Relevance is mediocre**: `vitamin water` → *"Milk, chocolate, lowfat, with added vitamin A"*. Needs `dataType` priority (Branded for packaged, Survey/FNDDS for generic) + our own re-ranking.
- Data is **CC0** — no licensing constraint. OFF is **ODbL**: display = "Produced Work" = attribution only; **reselling raw = share-alike risk**. Our `resale_ok` generated column already implements the firewall correctly.

### The cascade — ✅ already correct, verified in code

`local Drift → catalog → nutrition_products cache → [live USDA] → [OFF]`. `_maybeAutoSearchNutritionProducts` (`food_search_controller.dart:365-376`) only fires the cache when `local + catalog < 5`. **We never hit an external API before exhausting local + our own DB.** Live USDA slots in *after* a cache miss, preserving the order.

---

## 10. MERGED ROADMAP (supersedes the 7-03 doc's §7)

Reconciles this audit with `food-formula-plan-architecture-audit.md` (2026-07-03). See that doc's status header for what shipped/reversed.

### The three axes — keep them straight

| Surface | Axis | Pool | Filter |
|---|---|---|---|
| **Add/Swap (plan)** | run phase — `before_run`/`during_run`/`after_run` **+ sport** | `template_foods` + Feed + endurance user foods | `fuelOnly` (during), `all` (else) |
| **Carb loading** | **meal type** — breakfast/lunch/dinner/snack | `carb_loading_foods` (global, 27 seeded, real carbs) | *none today — should be carb-appropriate* |
| **Food logging** | **none** — no phase, no product type shown | everything | `generalFirst` (**ranks, never hides** — correct) |

These are *different taxonomies*, not one taxonomy used three ways. `carb_loading_foods.meal_types text[]` vs `user_foods.categories category_enum[]` are orthogonal.

### Phase 0 — Land the in-flight agent work (already written, just needs review)
0a. Review + merge `claude/fix-39fe3fdb-food-search-variant-title` (**highest user impact — the only silently-wrong-data defect**).
0b. Rebase + merge `claude/fix-39fe3fdb-multi-word-search-filter` (conflicts with 0a — same file). It extracts `lib/shared/utils/search_token_matcher.dart` and **removes 34 lines from `food_search_controller`** — a DRY win that aligns with this plan. **Adopt that util as the canonical tokenizer** and port it to the edge functions in Phase 1.

### Phase 1 — 🔴 SCORED CATALOG SEARCH — **the actual largest bug** (design: §9c)
1. **New Postgres RPC** `search_catalog_ranked(q, limit, product_type, product_type_id)`: tokenize → score `2×brand + 1×title` → threshold ≥2 → ORDER BY score DESC, `nutrition_confidence` as tie-break only. **NOT** `.or()` chaining (can't rank; produces the AND that fails). **NOT** FTS (proven 0 hits). **NOT** pgvector (§9c).
2. **Do not match `variant_title`** — keep displaying it. Kills flavour false-positives (`banana bread`: 5 → 0).
3. `search-catalog/index.ts` becomes a thin `.rpc()` caller; drop the `%${trimmedQuery}%` pattern (`:52,69`) and the `nutrition_confidence` primary sort (`:71`).
4. Mirror the Dart singularization (`search_token_matcher.dart`, Phase 0b) in SQL so client and server agree.
5. Extend `search-catalog/index.test.ts` (exists, BDD `describe`/`it`, tests extracted pure fns). **Deno 2.7.11 is installed locally** — we can test; the auto-fixer couldn't.
6. Migration + `supabase functions deploy search-catalog` → dev, then prod.
7. **Verify (all 7 must return the right top hit):** `rx bar`, `sis go isotonic gel`, `honey stinger chews`, `precision hydration 1500`, `huma gel`, `untapped maple gel`, `science in sport beta fuel`. Plus `banana bread` → 0.
   *(`walnuts` / `vitamin water` will still miss — they're groceries, not Feed products. Only Phase 3's live USDA fixes those.)*

### Phase 2 — Dead code + the render fix (ships with Phase 3)
6. Delete `supabase/functions_old/` — 18 files, **7,620 lines** (7-03 P2-7).
7. Delete the `"discover"` analytics string (`log_meal_screen.dart:530`).
8. **Forward `onNutritionProductResultTap`** from `UnifiedMealSearchResults` → `UnifiedFoodSearchResults` (one param — **do NOT delete the wrapper**, see the corrections header) and delete the no-op OFF handler (`log_meal_screen.dart:769-772`).
   - Low impact alone (2 prod rows) — **its value is that it makes Phase 3's live USDA results visible** on logging + carb loading. Ship them together.

### Phase 3 — Cheap correctness
6. `meal_logs.slot` nullability: Drift v14 nullable vs PG `NOT NULL` (upload risk).
7. **`build_meal_screen` run-phase leak** — `_isMealLogContext` (`barcode_scanner_screen.dart:286`) only matches `'meal_log_discover'`, so `'build_meal_add_food'` falls through to `FoodDetailScreen`'s *"When would you eat this? Before Run / During Run / After Run"* picker (`category_selector.dart:41-67`). **One-line fix**; food logging must never show run phases.
8. Carb loading barcode crash → route to `createFromBarcodeScan` (§5).
9. Carb loading hardcoded `carbsPerServing: 30.0` → use real macros (§5).

### Phase 3 — One search fn, one set of clients (+ the live FDA tier)
10. Extract USDA/OFF/cache/`detectProductType` out of `lookup-product`'s 806 inline lines → **`_shared/food_sources/`** (NOT `_shared/nutrition/` — that name is the plan solver). No behavior change; verify barcode; commit.
11. Merge `search-catalog` + `search-nutrition-products` → **`search-foods`** (one ranked, deduped list; filter as a request param). Tokenize the cache read here — low value alone (2 rows), free as part of the merge.
12. **Live external tier — USDA ∥ OFF in PARALLEL, merged (not a strict fallback).** They're complementary corpora; neither wins (§9c). Fires only after local+catalog+cache come up thin.
    - **USDA**: `/foods/search` **one call** (`foodNutrients` is in the search response; `/food/{fdcId}` only on tap). `dataType` priority: Branded for packaged, Survey/FNDDS for generic. **⚠️ 1,000 req/hr PER IP** and an edge fn shares one IP — keep the thin-results gate, cache aggressively, consider asking FDC for an elevated limit. **Verify the 3,600/hr figure in memory — research says 1,000.**
    - **OFF**: migrate `cgi/search.pl` → **Search-a-licious** (≈3× reliability, full `nutriments` in one call). **Do NOT fall back to legacy** — same corpus, worse reliability (§9c). Wrap in try/catch: complex Lucene can 500. Self-throttle (limit undocumented).
    - **Re-rank both with our own scorer** — USDA's native relevance is poor (`vitamin water` → chocolate milk).
    - **Write-through to `nutrition_products`**; `resale_ok` keeps the ODbL firewall intact.
    - Move OFF **server-side** (device calls it directly today; CORS-blocked on web).
13. **OFF correctness — do this even if the migration slips:**
    - (a) **Stop swallowing failures silently.** `food_search_controller.dart:287-297` catches, logs, and renders **"No foods found"** — identical to a genuine miss. Show a real error/retry state. **Confirmed in the dev app: first tap returned nothing, second tap returned Pringles.**
    - (b) **Retry with backoff** — legacy is ~50% flaky above 10 req/min.
    - (c) **Language/country filter** — results come back French/Dutch ("Aardappelchips"). Note `langs=en` did **not** work in testing; needs `countries_tags` or client-side filtering.
14. **Pass the catalog `product_type` filter** — exists (`catalog_search_service.dart:143-146`) but `SharedFoodSearchService.searchCatalog(query)` drops it (7-03 P1-6, still open).

### Phase 5 — Carb loading data model
13. **Delete `carb_loading_user_foods`** (§5b) — fold into `user_foods` + a `meal_types` column. Repoint `carb_loading_day_meals.carb_loading_user_food_id` → `user_foods`; keep the XOR check.
14. Delete `CarbFoodsList` — **extract the 8g/kg target math first**. Surface `carb_loading_foods` as the recommendation rail (filtered by `meal_types`).
15. Carb loading: call `setFilter` (stop running unfiltered).
16. De-dupe `_parseMealTypesArray` — currently copied verbatim in **3** files.

### Phase 6 — Sport-aware categories (own project; see §6b)
17. `nutrition_plan_mapper.dart:142,167` → sport-aware section ids; then `CategoryMatcher`; then re-categorize `template_foods`. **No DB migration needed** — the enum already has `during_bike`/`during_swim`.

### Phase 7 — Structural debt
18. Collapse the 4 `user_foods` write paths onto `UserFoodsRepository`.
19. Join `meal_logs.items` → `user_foods`.
20. 7-03 P1-4: before-phase **pin-first** (still an overlay, `before-phase.ts:297`).
21. 7-03 P2-8: retire legacy `foods` table (`getEssentialFoods` still live).

### Explicitly DO NOT TOUCH
- **`swap_food_controller._filterForRecommendations`** (§6c) — product_type ∩ category matching is correct and load-bearing.
- `FoodRecommendationService.getRecommendations()` is a **decoy duplicate with no callers** on this path; "consolidating onto the service" would silently change behavior (it merges `userFoods` + `genericFoods`; the live path uses `templateFoods` only).
- `to_exclude_from_solver`, `is_deleted` (7-03 load-bearing list).
- Food-preference rip-out — **reversed 2026-07-08**, prefs are live.

---

## 5b. Does `carb_loading_user_foods` need to exist? — **No**

**It is a parallel copy of `user_foods`, not an extension.**

- **Has 3 columns `user_foods` lacks:** `source_food_id`, `source_user_food_id` (nullable, provenance-only — *not* a parent link, NULL for manual + barcode), `meal_types text[]`.
- **Missing 16+ that `user_foods` has:** calories/protein/fat/sodium/fluid, serving size/unit/amount, `categories`, `activity_types`, `product_type`, `is_electrolyte`, `to_exclude_from_solver`, plus `needs_upload`/`local_updated_at`.
- **NEVER SYNCED — live data-loss bug.** Zero matches in `lib/shared/services/sync/`; absent from `SyncDependencyGraph`; the Drift table has **no sync columns at all** (`carb_loading_user_foods_table.dart`), so it is structurally incapable of uploading. Custom carb loading foods are **device-local and lost on reinstall/device change.** The comment at `carb_loading_day_meals_table.dart:31-32` ("FK enforcement happens in Supabase") assumes a sync that was never wired.
- **Barcode scans throw away macros** — the scanner has calories/protein/fat/sodium; the table has nowhere to put them (`food_import_service.dart:98-123`).
- **~955 lines** exist solely to maintain it (repository 248, import service 346, domain 205, table 38, generated 118), plus ~half of `carb_loading_food_service.dart` is pass-through + `dynamic` branching to tell the two food classes apart.

**Verdict:** fold into `user_foods` + a `meal_types` column. Deleting it removes ~955 lines **and fixes the sync gap for free** — the alternative is writing a fifth sync handler for a redundant table.

> **Keep `carb_loading_foods`** (the *global* curated list, no `user_id`). The symmetry is `template_foods : user_foods :: carb_loading_foods : user_foods+meal_types`. Only the *user* half is redundant.

## 6b. Sport-aware categories — the DB is already ready

**`docs/dev_schema.txt:29`:**
```sql
create type category_enum as enum ('before_run', 'during_run', 'after_run', 'transition', 'during_bike', 'during_swim');
```

**No migration needed.** The enum already allows `during_bike`/`during_swim` (+ `transition` for brick T1/T2). The **backend already does this**: `SPORT_DURING_CATEGORY` maps `cycling → during_bike`, `swimming → during_swim` (`_shared/nutrition/constants.ts:156-164`), and `getCategoryForPhase` (:170-183) queries `[sportCategory, 'during_run']` — sport-first with a legacy fallback. **Only the Flutter client hasn't caught up.**

**The hardcode is deliberate and documented**, and `nutrition_sections_builder.dart:181` is the *wrong place to fix it* — it faithfully mirrors `nutrition_plan_mapper.dart:142,167`, which stamps `during_run` as the section id for every single-sport plan.

**Changing :181 alone breaks two data paths:**
1. `CategoryMatcher.matches('during_bike', 'during_run', 'During Run')` → false → **add/swap/delete silently no-op on cycling plans.** (A generic-`during` fallback is explicitly blocked by comment: it would apply one leg's edit to all legs.)
2. Recommendations go empty (`template_foods` are categorized `during_run`) → trips the widening fallback → also empty → **zero recommendations.**

**Correct order:** mapper → `CategoryMatcher` → re-categorize `template_foods` (or port the backend's `[sportCategory, 'during_run']` fallback to the client). Census: **386 occurrences / 71 files, ~85% data-tier.** Display is already sport-aware via `getSectionTitle()`. Note the enum value is **`during_bike`, not `during_ride`**.

## 6c. Add/Swap recommendations — confirmed, do not change

`swap_food_controller.dart:209-218` → `_filterForRecommendations` (`:261-288`) then `sortByPreferences`.

**Match = (same `product_type`) ∩ (`food.categories` contains the section's category).** Swap a gel in During → template foods where `productTypeId == 'gel'` AND `categories.contains('during_run')`. **This is the "similar product category" behavior and it works.**

Three load-bearing subtleties to preserve:
- **Add vs Swap differ.** `originalFoodId == null` (the **Add** case) never consults product_type — Add is a pure category filter. Product-type matching exists **only for Swap**.
- **Empty-intersection fallback widens to category-only** (`:281`) — ask to swap a gel, possibly get non-gels.
- **`after_run` disables category filtering entirely** (`:291`) — after-run swap = product-type match against the whole catalog.

Pool = `templateFoods` only; user foods appear in a separate unfiltered "My Foods" section (`:228`).
