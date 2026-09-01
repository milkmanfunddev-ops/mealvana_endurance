# 05 — `lib/features/meal_planning/` (Phase 4)

FOA: `presentation → application → domain ← data`. Controllers are `@riverpod` AsyncNotifiers using
`AsyncValue.guard()`. Strings via `ContentKeys` + `content_defaults.json` (do NOT copy `ai_coach`'s
inline-literal shortcut — its keys were never registered). `MealvanaSnackbar` only.

## 0. Reuse map (verified in the codebase)
| Need | Reuse | Notes |
|---|---|---|
| Streaming chat client | `ai_coach/data/ai_coach_chat_repository.dart` `_streamRequest` (NDJSON, 402 → `InsufficientCreditsException`) | generalize: endpoint + `kind` params; parse `status` lines |
| Chat message model | `AiCoachMessage` / sealed `AiCoachUiPart` (`fromJson` drops unknown kinds) | becomes `VanaMessage` / `VanaPart` with 10 kinds; add `replacePart(id)` (today append-only) |
| Chat controller/screen | `ai_coach_chat_controller.dart`, `ai_coach_chat_screen.dart` bubbles/avatar/thinking | extend, then `/jade` = `VanaChatScreen(kind: general)` |
| 402 paywall | `ai_credits/presentation/insufficient_credits_paywall.dart` `maybeShowInsufficientCreditsPaywall` | unchanged |
| Meal log write | `meal_logging/data/meal_log_repository.dart` `insertLog` | add `MealLogSource.plan` + `MealLog.planMealId` (Drift col + JSON) |
| Recents | `MealLogRepository.getRecentLogs` (dedupe by name in Dart) | Recents rail = local logs ∪ `plan_meals` by recency (prototype `getRecentMeals`) |
| Saved meals | `SavedMealsRepository.watchSavedMeals` (+ new cols `icon notes meal_types batch library_meal_id`) | My Foods rail |
| Read-mostly catalog cache pattern | `recipes/data/repositories/recipe_repository.dart` (SyncableRepository, 24 h staleness) | pattern only — catalog targets `meal_library` via RPC, not `recipes` |
| Swipe rows | `Dismissible` + `lib/shared/widgets/swipe_action_background.dart`; example `dismissible_food_item.dart` | Plan tab swap/remove |
| Cards/buttons/chips | `BaseCard`, `KylePrimary/Secondary/TertiaryButton`, `KyleSelectionButton<T>`, `KyleSegmentedControl`, `KyleSwitch`, `KylePlusMinusControl` (stepper), `KyleTextField` | import by path — the `kyle_design.dart` barrel is stale |
| Food icons | `KyleFoodIcon` (`KyleFoodType` 12 values) | **insufficient** — add `MealIconGlyphs` (23 keys, port the SVG paths from `meal-icons.tsx` as `CustomPainter` or `flutter_svg` assets) |
| Sheets | `showAdaptiveModal<T>()` (`lib/shared/utils/adaptive_modal.dart`) | dialog on wide, sheet on mobile |
| Targets | `dailyMacrosControllerProvider` (`DailyMacrosState.dailyMacros/weeklyMacros`) | Plan tab "today's target" line |
| Week workouts / next race | `calendarControllerProvider.notifier.currentWeekActivities`, `nextUpcomingEventProvider` | header context only; the server builds the real context |
| Profile diet/allergies | `userRepositoryProvider` → `UserPreferences.dietaryPreference/allergies` | greying allergen cards client-side (server already filters) |
| Weather | `WeatherService.getWeatherForecast` | not needed client-side (server) |

## 1. File tree
```
lib/features/meal_planning/
  domain/
    meal_type.dart meal_context.dart cooking_session.dart meal_icon.dart directions_origin.dart
    meal_ref.dart plan_meal.dart meal_plan.dart plan_rule.dart shopping_item.dart day_plan.dart day_target.dart
    meal_detail.dart user_memory.dart vana_conversation.dart vana_message.dart vana_part.dart (sealed, 10 kinds)
    ui_action.dart (sealed) vana_setting.dart plan_coverage.dart
  data/
    tables/meal_plans_table.dart plan_meals_table.dart user_memories_table.dart user_entitlements_table.dart (→ subscription)
    meal_plan_repository.dart          SyncableRepository key 'meal_plans' (plans + plan_meals, local-first edits)
    user_memory_repository.dart        SyncableRepository key 'user_memories' (settings + facts; embeddings server-only)
    meal_library_remote_data_source.dart  RPC search_meals / library_pair_support / set_meal_feedback; get_meal action
    vana_chat_repository.dart          generalized from ai_coach (endpoint, kind, NDJSON incl. status)
    vana_action_client.dart            POST vana-action, returns parts + extras; maps 403/402/429
  application/
    meal_plan_controller.dart          @riverpod AsyncNotifier<MealPlan?> — active plan; edits (servings/remove/session/
                                       day slot/shopping toggle) local-first + upload; pick/swap/confirm remote-ack
    plan_day_controller.dart           day grid for a date (set/clear slot, plan_day)
    meal_catalog_controller.dart       rails (Recents/My Foods/Assemblies/Recipes) + search + filters (debounce 350 ms)
    meal_detail_controller.dart        get_meal + feedback (optimistic vote) + saved-meal notes
    shopping_list_controller.dart      items grouped by aisle; checked/have toggles local-first
    vana_chat_controller.dart          per conversation; opener; send; chips; folds `batch` parts into MealPlanController
    vana_conversations_controller.dart list/create by kind
    vana_settings_controller.dart      batch_cooking / show_macros / memories
    cooking_session_controller.dart    step index, timers, wake lock (wakelock_plus), alarm (audioplayers or system)
    day_notes_service.dart             read day_notes; if stale, poll home after 7 s (never generate client-side)
    meal_icon_classifier.dart          port of meal-icon.ts
    plan_coverage_service.dart
    home_service.dart                  get_home action → HomePayload (day guidance, staples, target, vana note)
  presentation/
    screens/food_screen.dart           tabs Plan · Meals · Shopping (+ Formulas → existing formula kit route)
            plan_tab.dart meals_tab.dart shopping_tab.dart
            meal_detail_screen.dart cooking_mode_screen.dart swap_meal_screen.dart recents_screen.dart
            vana_chat_screen.dart vana_conversations_screen.dart vana_settings_screen.dart
    widgets/ vana_message_card.dart plan_tile.dart plan_list.dart plan_summary.dart tile_sheet.dart
             staples_card.dart day_card.dart meal_picker_carousel.dart meal_card.dart picker_chips.dart choice_chips.dart
             plan_bar.dart review_sheet.dart meal_sheet.dart swap_picker.dart confirmed_card.dart rule_chip.dart
             shopping_list.dart memory_drawer.dart catalog_row.dart meal_rail.dart meal_rail_card.dart servings_sheet.dart
             meal_icon_tile.dart slot_chip.dart stepper.dart timer_chip.dart step_progress_dots.dart
```

## 2. Drift v19 (on top of develop's v18)
- `meal_plans` — every Supabase column (jsonb → `TEXT` JSON: `rules shopping days day_notes`) +
  `needs_upload local_updated_at`. Unique `(user_id, week_start)` only for status≠archived is a
  **partial** index on the server → **never `onConflict` on it; upsert `onConflict:'id'`**.
- `plan_meals` — all columns + `is_deleted` (local tombstone; server deletes are hard via cascade) +
  `needs_upload local_updated_at`.
- `user_memories` — all columns except `embedding` + `needs_upload local_updated_at`.
- `meal_logs` — `addColumn('meal_logs','plan_meal_id','TEXT')`.
- `saved_meals` — `addColumn` `icon notes meal_types(JSON) batch library_meal_id`.
- `user_entitlements` (Phase 3).
- `onUpgrade`: `if (from < 19) { ensureTable(mealPlansTable); ensureTable(planMealsTable);
  ensureTable(userMemoriesTable); ensureTable(userEntitlementsTable); addColumn(...) }`. Then codegen
  (`dart run build_runner build --delete-conflicting-outputs`); `schema_versions.dart` is generated —
  don't hand-edit. Add the v19 `SchemaVerifier` migration test.
- `meal_library` is **not** mirrored (1,922 rows + pgvector; search is server-side). Catalog results
  and `MealDetail` are cached in memory per session (`keepAlive` family providers) so a detail page
  or cooking mode opened once survives a network blip.

## 3. Write-consistency rules (per `docs/technical/write-consistency-policy.md`)
| Action | Mode | Why |
|---|---|---|
| set_servings, remove_meal, set_session, toggle_shopping, set_day_slot/clear, set_setting, add_comment, delete_memory, saved-meal notes | **local-first** (`needs_upload`, replayed by `uploadDirtyRecords` as `vana-action` calls or direct upserts) | pure user-owned rows |
| pick_meals, swap_meal, plan_day, new_plan, log_from_plan | **remote-ack** (needs library lookup / servings decrement / meal_logs write) | offline → `MealvanaSnackbar.showWarning` "Needs a connection" |
| confirm_plan | **remote-ack** (`confirm_meal_plan` RPC via `vana-action`), then shopping list shown | cross-surface: Shopping tab + Vana see the same list |
| chat turn | online only | model |

`uploadDirtyRecords()` returns a silent `UploadResult.failed()` on exceptions — **always check it**.

## 4. Screens — behaviour spec (mirror of the prototype routes)
**Food (`/food`)** — header "Food", segmented Plan · Meals · Shopping (`KyleSegmentedControl`);
detail routes hide the header. Entry = new tab in `TabsScreen` (mobile pill + web rail) when Pro-unlocked.

**Plan tab** — `get_home(today)`: `VanaMessageCard` (day note; tap → general chat; if `stale` re-poll
in 7 s) → "This week's plan" → `PlanSummary` + `PlanList` (swipe left: Swap → `/food/swap/:id`; Remove →
Undo snackbar re-picks) / tap → `TileSheet` (stepper · Swap · Remove) → else dashed empty card +
compact `StaplesCard` → buttons "Add meal" (→ Meals) · "New meal plan" (→ `/vana?c=new&mode=meal_planning`)
→ "Confirm plan · build shopping list" while draft. Today line "at least Ng carbs · Ng protein · N kcal"
from `dailyMacrosController`.

**Meals tab** — `MealCatalog(mode: add)`: search icon → debounced query → flat results; filter popover
(meal type × assembly/recipe); rails Recents (→ `/food/meals/recents`) · My Foods · Assemblies ·
Recipes; allergen-excluded cards greyed; Vana CTA row "Want me to build the week instead?".

**Meal detail (`/food/meals/:id`)** — hero image (hide on error; CC attribution caption) · tags ·
why · thumbs up/down (optimistic `set_meal_feedback`; −1 shows "Vana won't suggest this again") ·
attribution card + "See the original recipe" · ingredients (one serving / makes N) · "How to cook"
numbered steps with origin badge (`ai_generated` sparkle + tooltip, `assembly_simple`, `alt_source`,
verbatim "as published by X") · "Start cooking" (if steps) · saved-meal "Your directions" editable
notes · swaps chips (local) · macros disclosure ("approximate") · `?swap=` → "Swap in" + stepper,
else save-to-mine hint (heart is unwired in the prototype — implement as `SavedMeals` insert).

**Cooking mode (`/food/cook/:id`)** — phases overview → cooking → done. Overview: hero, N steps · prep
· servings, AI-steps disclaimer, ingredients card, "Start · step 1 of N". Cooking: progress dots, big
step text, timer chips parsed from the step (start/pause/cancel, local notification + vibration on
ring), oversized left/right tap zones, swipe, ingredients drawer with strike-through, **wake lock**
held only in this phase, Back/Next footer. Done: thumbs, Start over, Done. No steps → empty state.

**Shopping tab** — item count · "Totals for N servings · M meals" · optional "I left X off — you have
it. Add back" row · aisle groups (Produce · Protein · Dairy · Bakery & Grains · Pantry · Spices · Frozen ·
Beverages · Other) with checkbox + qty + "have it" chip (local-first toggles) · "Share" (share sheet
plain text) · "Order pickup" hidden (not v1).

**Swap (`/food/swap/:planMealId`)** — header card "Replacing X", `MealCatalog(mode: swap)` same
meal type, not-in-plan; pick → `swap_meal` (+ `set_servings`) → back to Plan.

**Vana chat (`/vana?mode=&c=`)** — header (back, avatar w/ thinking pulse, "Vana" / "Vana · Meal plan",
+ new, list). Planning with `c=new`: create conversation, opener streams (loading "Vana is looking at
your week…"). Body: user bubbles; assistant turns = text (bold inline) + `status` line + parts via
`VanaPartRenderer`; planning parts ordered text-first. `PickerChips` client-drawn (02 §6). `PlanBar`
pinned above composer, **starts minimized** and re-minimizes on each new turn; expanded tiles have ×
and stepper; "Review plan" → `ReviewSheet` (grouped by session when batch cooking on; steppers;
Confirm; disabled once confirmed); tap tile → `MealSheet` (stepper · Swap → inline `SwapPicker` ·
Remove). Composer placeholder per kind. `ConfirmedCard` after confirm (link to Shopping). Errors:
offline bubble; 429 → "Give me N seconds"; 402 → credits paywall; 403 → `/pro`.
General mode: empty state with 3 example chips; no plan bar; `askChoice ["Start a meal plan","Not now"]`.

**Conversations (`/vana/conversations`)** — segmented "Ask Vana" / "Meal plans", rows title · date ·
summary, "New…" button, gear → settings.

**Vana settings (`/settings/vana`)** — `KyleSwitch` Batch cooking, Show macros; "What Vana knows" list
with delete. Link from the existing Settings screen.

## 5. Router / tab edits
`app_router.dart`: routes `/food` (with sub-tabs via `?tab=`), `/food/meals/recents`, `/food/meals/:id`,
`/food/cook/:id`, `/food/swap/:planMealId`, `/vana` (replaces `/jade`; keep `/jade` → redirect),
`/vana/conversations`, `/settings/vana`; pro redirect (04). `tabs_screen.dart`: index getters
(`_foodTabIndex`), `screens` list, `onFoodTap`, `FloatingActionButtonsBar` new param, rail destination,
`/main?tab=food`. Food icon in the pill: reuse the `KyleFoodIcon` glyph style.

## 6. Content keys
`meal_planning.food_title`, `.tab_plan/.tab_meals/.tab_shopping`, `.empty_plan_title/.body`,
`.btn_add_meal/.btn_new_plan/.btn_confirm`, `.today_target_line`, `.chip_like_these/.chip_next/.chip_other/
.chip_something_else/.chip_thats_my_week`, `.filter_no_recipe/.filter_protein/.filter_under_20`,
`.picker_placeholder_planning/.general`, `.vana_offline`, `.needs_connection`, `.confirmed_toast`,
`.shopping_share_title`, `.cook_start/.cook_next/.cook_back/.cook_done/.cook_ai_disclaimer`,
`.detail_thumbs_down_note`, `.settings_batch/.settings_macros/.settings_memories_body`, `.pro_required`.

## 7. Estimates (one engineer, after 02/03 are done)
domain + Drift + repos 3 d · controllers 3 d · chat screen + parts + plan bar 4 d · plan/meals/shopping
tabs 3 d · detail + cooking mode 3 d · swap/conversations/settings 1.5 d · router/tab/gate 0.5 d ·
tests 3 d ⇒ **≈ 3½ weeks**. Two engineers: chat stack ∥ catalog/detail/cook — ≈ 2 weeks.
