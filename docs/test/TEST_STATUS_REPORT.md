# Test Status Report — updated 2026-06-30 (after the coverage waves)

Grounded audit (counts from `find`/`grep`). Supersedes the earlier version.

## Totals
- **Dart tests:** ~175 files (was 139 this morning).
- **Deno edge-fn tests:** ~73 files (was 53).
- **Full Flutter unit/widget suite:** green (last full run +1,393; +~600 added since
  across coach/calendar/carb/meal/integrations/auth/settings/events/templates/
  user_foods/content/education/weather + salvage/repair).
- **Edge fns:** ~26 of 33 functions now have tests (food/catalog, AI, garmin+sync,
  user/weather/email, macros/plan engine).

## Test types — all four present
Local (Deno edge-fn) ✅ · Widget smoke+seeded ✅ · Flutter unit/service ✅ ·
Integration (Patrol + live `--e2e` + python) ✅ · Migration ✅.

## Coverage now — almost everything has tests
**🟢 Covered:** nutrition_plan (29), formula_kit (15), coach_mode (5), fuel_timeline (5),
activities (4), integrations (4), settings (3), content (3), daily_macros (3, *obsolete*),
ai_credits/auth/calendar/carb_loading/education/meal_logging/personal_templates (2 each),
app_startup/events/jade/onboarding/race_checklist/user_foods/weather (1 each) + `new_sync`
(24, sync/repos) + the nutrition engine (12 Deno).

**🔴 Remaining 0-coverage (the only real gaps left):**
- **`recipes`** — has `recipe_service` + `recipe_repository` → CRUD worth testing.
- **`pro_version`** — IAP/purchase logic (revenue-critical) → worth testing.
- **`nutrition`** — domain models only (`nutrition_data`, `food_item`) → light model tests.
- **`feedback`, `sharing`, `barcode_scanning`** — thin/UI/Patrol-tier (low value as units).
- **`food_preferences`** — being phased out (intentional skip). **`notes`** — unbuilt (README only).

## ♻️ Obsolete tests / code (remove or replace)
- **`daily_macros` (4 test files)** — `DailyMacrosScreen` is **no longer routed** (Fuel
  Timeline replaced the Nutrition tab). These test a dead screen → delete with the
  screen, or fold the still-relevant macro-math assertions into fuel_timeline tests.
- **4 legacy edge functions** — `generate-macros`, `generate-macros-v3`,
  `generate-nutrition-plan`, `generate-nutrition-plan-v2` (0 refs in `lib/`; app uses
  v4/v3). No tests exist for them; **delete the functions**.
- **`test/integration/test_nutrition_plan_v2.py`** — tests legacy v2 → delete or
  bump to v3/v4.
- **`supabase/functions/_archived` + `_archived_tests`** — archived; prune.
- **`test/local_edge_functions/`** — compat harness that just delegates to
  `run-algorithm-tests.sh`; verify CI still references it, else remove.

## 🔧 Tests that could be combined / improved
- **daily_macros ↔ fuel_timeline overlap** — both cover the Nutrition tab; consolidate
  into fuel_timeline once daily_macros is deleted (removes duplicate macro-table assertions).
- **Edge-fn "handler-copy" pattern** — several new Deno tests re-implement the handler
  logic inline rather than importing the real exported handler, so they can drift from
  production. *Improvement:* refactor each `index.ts` to export a pure `handler(req, deps)`
  and have the test call it (catches real regressions, not a copy).
- **smoke vs seeded** — keeping both is intentional (renders vs values); not redundant.
  But the per-screen smoke files could share more via the harness (minor DRY).
- **Repeated Patrol auth/nav helpers** — `_ensureAuthenticated`/`_fillField`/
  `_returnToCalendar` are copy-pasted across flow files → extract to a shared
  `integration_test/helpers/` (Phase-0 item).

## ▶ What's LEFT for "full coverage"
1. **The remaining gap features** — `recipes` (CRUD), `pro_version` (IAP), `nutrition`
   (models); optionally `feedback`/`sharing`. (Small wave.)
2. **Patrol journeys** — finish formula-create verify (in progress); add onboarding,
   integrations-connect (Android), settings-persists, coach cross-user.
3. **Edge-fn LIVE integration** — the unit tests mock; live runs needed for DB queries
   (get-foods/search-catalog/events), AI gateway round-trips, garmin, delete-user cascade.
4. **Delete the obsolete** (above) so coverage isn't measured against dead code.
5. **CI gating** — run all suites per-PR (nothing gates them yet).
6. **Fix/decide the open bugs** — Calendar/CarbLoading mock-data (product call),
   Resend key rotation, the `save-user-food` deploy check (`NEED_FROM_LEE.md`).

> Bottom line: the app went from "mostly smoke" to **broad unit/service/edge coverage**
> in one day — ~36 new test files, ~25 real bugs found (incl. data-loss `copyWith`, a
> security hole, and two features rendering mock data). What's left is a **small gap
> wave (recipes/pro_version/nutrition)**, **Patrol breadth**, **live edge-fn integration**,
> **obsolete-code cleanup**, and **CI gating**.
