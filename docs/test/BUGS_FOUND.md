# Bugs Found by the Test Suite

Living list of bugs/issues surfaced while building the widget smoke suite +
edge-fn tests (2026-06-25 onward). The widget smoke tests are deliberately
designed to FIND bugs: every crash, render overflow, infinite loader,
null-subtype error, or dead-code screen is logged here.

Severity legend: **crash** (throws on build) · **overflow** (RenderFlex) ·
**hang** (never settles) · **dead-code** · **other**.

## ✅ Resolution (2026-06-25)

**All 17 confirmed bugs are fixed** (verified: full widget suite `+159 ~1` green —
only BarcodeScanner skipped for camera; `flutter analyze lib/` clean). Highlights:
the `MacroTargetsController` dispose bug (#4) now captures deps before disposal
(canary un-skipped & passing); `ActivitiesListScreen` (#11) no longer dumps a
151k-char exception to the UI; #12/#16 were re-classified as a harness gap (not
prod) and fixed once in `ScreenUtilInit`; all 7 overflows fixed with overflow
checks re-enabled at 390; 3 dead screens deleted; the SweatProfile unit-label
bug (#17) has a regression test. **Deferred (not bugs to fix):** #15 FoodPrefs
FOA (screen being phased out) and the deep-`../` import codemod (only Survey #9
actually broke — fixed; the rest are a lint/codemod follow-up).

## Confirmed

| # | Screen / Area | Severity | Detail | Status |
|---|---|---|---|---|
| 1 | `SportPreferencesScreen` (onboarding) | dead-code + overflow | Zero references in `lib/`; still `context.push('/onboarding/food-preferences')` (a removed route); overflows 104px at multiple sizes. Recommend deletion. | open |
| 2 | `PostOnboardingAuthScreen` | overflow | 14–44px horizontal overflow at 390px width (multiple Rows). | open |
| 3 | `EventsListScreen` | overflow | Loading/skeleton state overflows at 390px — unconstrained Column/ListView in the loading branch. | open |
| 4 | `MacroTargetsController` (used by AdjustMacros / CyclingInput / SwimmingInput) | functional (MEDIUM) | `_scheduleCleanupIfNeeded()`'s `Future.delayed(2s)` closure calls `ref.read(...)` after disposal. **It's wrapped in try/catch → NOT a production crash**, but the `StateError` is swallowed so **draft-activity cleanup silently never runs** (orphaned drafts) + leaves a test timer. Fix: capture deps before dispose. `macro_targets_controller.dart:~2266`. Being fixed. | fixing |
| 5 | `NewActivityScreen` | overflow | SportSelector tab row (Running/Cycling/Swimming/Brick) overflows 29px at 390px. | open |
| 6 | `ActivityDetailScreen` | overflow | Two Rows overflow at 390px — schedule-info (39px) + action buttons (112px). | open |
| 7 | `CurrentPlanScreen` | dead-code | Entire file is commented out; zero references. Delete. | open |
| 8 | `CarbLoadingScreen` | other | Uses deprecated `withOpacity()` (use `withValues(alpha:)`). | open |
| 9 | `SurveyScreen` | **crash (compile)** | Invalid import: 9× `../` resolves above filesystem root — file **cannot compile**. `survey_screen.dart:9`. One-line fix to a `package:` import. (Latent because the screen isn't routed anywhere.) | open |
| 10 | `DailyMacrosScreen` | overflow | 3 Rows overflow at 390px (2 / 19 / 7.3px) — weekly macro bar / nutrition summary rows. Previously invisible (existing layout test didn't enforce overflow). | open |
| 11 | `ActivitiesListScreen` | overflow | `AsyncLoading` state: unconstrained `Column` in Scaffold body overflows ~159,692px vertically. | open |
| 12 | `ShareNutritionPlanScreen` | ~~crash~~ → not-a-prod-bug | `flutter_screenutil` `.sp` → `LateInitializationError` ONLY without a `ScreenUtilInit` ancestor. **`ScreenUtilInit` IS at the app root** (`root_app_widget.dart:97`) so production is fine — this was a **test-harness gap**. Fixed: `smokeScreen`/`pumpSeeded` now wrap in `ScreenUtilInit`. | resolved (harness) |
| 13 | `WeatherDetailScreen` | crash (FIXED) + dead-code | `SingleTickerProviderStateMixin` can't provide 2 tickers (TabController + explicit AnimationController) → runtime throw. **Agent already fixed** mixin→`TickerProviderStateMixin` in prod. Screen is dead code (no router, hardcoded mock data, dead animation) — candidate for deletion instead. | fixed/decide |
| 14 | `SweatProfileScreen` | overflow | 35px Row overflow at 390px — needs Flexible/Expanded. | open |
| 15 | `FoodPreferencesScreen` (settings) | FOA violation | `initState→_loadFoods()` calls repo/auth/db/sync providers directly in UI (`Future.wait(...).timeout(15s)`). Belongs in a controller. | open |
| 16 | `SportSettingsScreen`, `DebugScreen` | ~~crash risk~~ → not-a-prod-bug | Same as #12 — `ScreenUtilInit` is at the app root, so production is fine. Resolved by the harness fix. | resolved (harness) |
| 17 | `SweatProfileScreen` | other (display) | Unit-toggle left label is `_showOzHr ? 'mL/hr' : 'mL/hr'` — **both ternary branches identical** (`sweat_profile_screen.dart:445`). Switching to oz/hr never updates the left label. Copy-paste bug. | open |

## Systemic patterns (worth a single sweep)

- **screenutil-without-init crash class** (#12, #16): screens using `flutter_screenutil`
  extensions with no guaranteed `ScreenUtilInit` ancestor crash with
  `LateInitializationError`. Audit all `.sp/.h/.w` usage; migrate to
  `Theme.of(context).textTheme` / `AppSpacing` or guarantee the wrapper.
- **fragile deep relative imports** (#9): ~20+ files use `../../../../../..`-style
  imports to reach `shared/widgets/kyle_design/`. At least `SurveyScreen` won't
  compile from it. Codemod all to `package:mealvana_endurance/...` imports.
- **390px overflows** (#2, #3, #5, #6, #10, #14): many screens clip horizontally
  at standard phone width — a recurring responsive-layout gap.
- **dead-code screens** (#1, #7, #13): `SportPreferencesScreen`, `CurrentPlanScreen`,
  `WeatherDetailScreen` — unrouted, zero/stub usage. Delete.

> ⚠️ A subagent modified production code (`weather_detail_screen.dart`, #13) to fix
> the ticker crash. Sound fix, but flagged for review since the screen may instead
> be deleted.

## UX / low-severity (no crash)

- `FormulaDetailScreen` not-found path (deep-link to an id not in local cache),
  confirmed by seeded content tests:
  - renders "Formula not found." with **no retry/refetch action** (dead-end).
  - **app-bar title stays "Formula"** (the init value is only overwritten inside
    `whenData`; never set on the null branch) — poor screen-reader labelling.
  - **`trackDetailViewed` analytics still fires** on the not-found branch →
    logs `formula_detail_viewed` with a non-existent `template_id` (data noise).
- `CoachPortalScreen`: auto-selects the first athlete via
  `addPostFrameCallback`; sidebar + detail panel can briefly desync / flicker if
  the dashboard loads slowly.
- `ActivityDetailScreen`: the app bar shows `eventName ?? 'Activity Details'` and
  **never renders `Activity.title`** — non-event activities (e.g. "Long Run")
  show a generic "Activity Details" header with no at-a-glance identification.
- `CarbLoadingScreen`: renders **hardcoded mock strings** ("3-Day Loading
  Protocol", "Day 1", …) with no live controller/data pathway (also #8
  deprecated `withOpacity`). Needs real data wiring or to be treated as a stub.

## Notes / lower-confidence

- `SwapFoodScreen` shows a perpetual loading spinner in widget tests (loads its
  catalog in `initState`; never resolves without seeded data). Likely by-design,
  but means it renders no content without a data provider — flagged for a
  fuller seeded test. Not counted as a bug.
- `EducationScreen` printed overflow at 320/834 in an early run but passes the
  390px check; possible narrow/wide responsive issue — needs a multi-size pass.

## 🔴 Features rendering MOCK data (HIGH — found 2026-06-30)

Seeded content tests proved these screens **ignore their controllers and render
hardcoded placeholder data to every user** — they look shipped but aren't wired:

- **`CalendarMonthScreen` week view** — `_getMockTodaysActivities()` /
  `_getMockUpcomingEvents()` return fixed strings ("10 MILE RUN", "KULTURE CITY
  HALF MARATHON", "Nov 22"…); `CalendarController` is never watched. Every user
  sees the same fake activities/events.
- **`CalendarMonthScreen._hasEventsOnDay`** — event dots come from
  `day % 3 == 0 || day % 7 == 0`, not real data.
- **`CalendarMonthScreen` week view** — bare non-scrollable `Column` overflows
  96px at standard phone size.
- **`CarbLoadingScreen`** — entire screen is hardcoded ("3-Day Loading Protocol",
  Day 1/2/3 cals from `MockMeal` structs); `CarbLoadingController` is imported but
  never used.
- **`CarbLoadingScreen` nutrition dialog** — fabricates macros: protein =
  `calories*0.15`, fat = `calories*0.08` (e.g. 320-cal oatmeal → 48g protein, ~4×
  reality). Made-up coefficients, not nutrition data.

> These are product/functionality bugs (the features need real wiring), not test
> bugs — surfaced because content tests assert *values*. Confirm scope with Lee.

## Flutter unit-test sweep bugs (2026-06-30)

- **`coach_chat_controller` — production crash on dispose (HIGH, FIXED).** `ref.read`
  inside `onDispose` → `AssertionError: Cannot use Ref … inside life-cycles` in
  Riverpod 3.x — crashes every time the chat screen is left. Agent fixed it (cache
  the service before registering `onDispose`).
- **`ref`-in-`onDispose` pattern — SWEPT, contained.** Repo-wide grep found only
  2 instances (`coach_chat_controller` + `MacroTargetsController` #4) — **both now
  fixed**. Other `onDispose` sites (oauth_service, auth_listener_service,
  adjust_macros/new_activity screens, food_search_controller) dispose
  subscriptions/controllers with no `ref` access — safe.
- `coach_reports` — `ReportsDateRange.custom` label shows `end + 1 day` (exclusive
  upper bound leaks into the UI label). LOW.
- **`CarbLoadingPlanSimple.fromJson` crash (MEDIUM).** `json['daySelections'] as
  Map<String,dynamic>?` throws `TypeError` on a `Map<dynamic,dynamic>` (from JSON
  bytes / `{}` literal). Fix: `Map<String,dynamic>.from(... ?? {})`. (`carb_loading_plan_simple.dart:133`.)
- **Carb-loading protocol logic (MEDIUM).** `isCarbLoadingActive` hardcodes a
  **2-day** window (`raceDate - 2d`) regardless of protocol length → a 3-day
  protocol's day -3 isn't "active" (`carb_loading_plan_simple.dart:236`). And
  `getCarbProtocolForDay` on a 2-day protocol returns **11 g/kg for race day
  (daysBeforeRace=0)** instead of the 8 g/kg default (unreachable fallback) —
  duplicated in `carb_loading_service.dart:493` + `calendar_service.dart:375`.
- `CalendarController._getWeekStart` relies on Dart's negative-day overflow for
  month-start Sundays (works, but fragile/undocumented). LOW.
- `meal_logging` (note, not a bug): `logRecipe` with null sodium yields
  `log.sodiumMg == 0.0` (not null) — callers checking `== null` get a false negative.
- **`WeatherDetailScreen` (live one) — invisible AppBar (display).** AppBar
  `backgroundColor: baseCream` + `foregroundColor: Colors.white` → "Weather
  Forecast" title + back button are white-on-cream (invisible in light mode).
- **`RecipePickerScreen` — FOA violation.** `ensureSynced` + `getAllRecipes`
  business logic runs in `didChangeDependencies` (setState-based), bypassing
  Riverpod — same class as #15.
- `JadeChatController` (testability note): `eventStream` must emit across async
  gaps; `Stream.fromIterable` emits synchronously and hangs the test pump loop —
  any mock/real path using it will stall silently.

## Edge-function bugs (2026-06-30 coverage sweep)

- **`save-user-food` — MISSING AUTH ENFORCEMENT (HIGH / security).** Uses the
  service-role key and trusts `user_id: requestData.device_id` from the body
  without checking it against the JWT. **Any caller can write food records
  attributed to another user.** Fix: use anon key + RLS, or validate `device_id`
  against the authenticated JWT `sub`.
- **`analyze-meal-photo` — `not_food` 422 is dead code.** When the model returns
  a non-food result, `generateObject` throws a **zod** error whose message is
  `"Required at items..."` — which doesn't contain `not_food`/`not food`, so the
  catch's 422 branch never fires and the user gets a **500** for photographing
  non-food. Fix: make `not_food` an optional schema discriminator, or
  `generateText` + manual parse. (`analyze-meal-photo/index.ts:206-215`.)
- **`lookup-product` — sodium 0 → null (MEDIUM).** `sodium_100g ? ... : null` —
  a legitimately sodium-free product (OFF returns `0`) becomes `null` (unknown)
  instead of `0` (confirmed zero). Same falsy-on-0 trap likely elsewhere.
- **`search-catalog` — `has_nutrition` false for zero-cal items (LOW).**
  `!!(calories || carbs)` → electrolyte tablets (0 cal, 0 carb) read as "no
  nutrition data" in the UI though data is present.
- **`save-user-food` — `categories_saved` overcounts (LOW).** Reports the raw
  input count; unknown category IDs are filtered before write (`[1,99]` saves 1,
  reports 2).
- **`search-public-events` — untrimmed query echoed (LOW).** Searches `query.trim()`
  but returns the original untrimmed `query` to the client.
- **`send-nutrition-plan-email` — hardcoded Resend API key fallback (MEDIUM / secret).**
  `Deno.env.get('RESEND_API_KEY') || 're_DHjg7ayY_…'` — a live key is committed to
  source as the fallback. Rotate it + remove the fallback (see NEED_FROM_LEE).
- **`create-user` — `gut_training_level` required-but-defaulted (MEDIUM).** Validated
  unconditionally against the enum → 400 when omitted, even though line 87 defaults
  it to `'moderate'`. Guard the validation with an `!= null` check.
- **`get-weather-forecast` — `latitude=0` rejected as falsy (LOW).** `if (!latitude…)`
  → equator coordinates fail. Use explicit null/undefined checks.

## Edge-function / nutrition-engine (from prior sessions, still open)
- After-phase hydration/sodium severely under-delivered (task #23).
- Stacked-allergy / vegan compliance broken (task #24).
- (See `testing-build-plan-2026.md` Progress Log for full context.)

---
*Appended automatically as smoke-suite agents report; see also
`testing-build-plan-2026.md`.*
