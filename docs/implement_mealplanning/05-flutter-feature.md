# 05 — `lib/features/meal_planning/` (Phase 4)

## Status — Phase 4b (data + application) **built 2026-09-01** (branch `mealplanning`, dev only)
Phase 4a (`domain/`) and 4b (`data/`, `application/`, Drift v20, sync registration) are in code and unit
tested (`test/features/meal_planning/`, `test/migrations/meal_planning_v20_migration_test.dart`).
Phase 4c (`presentation/`, router, tabs, content keys) is next. Nothing under `supabase/` changed.

| Piece | Where | State |
|---|---|---|
| Drift **v20** | `lib/shared/database/tables/{meal_plans,plan_meals,user_memories}_table.dart`, `meal_logs.plan_meal_id`, `saved_meals.{icon,notes,meal_types,batch,library_meal_id}`, `database_schemas/drift_schemas/drift_schema_v20.json` | in code; `from < 20` step idempotent; schema-guard test pinned. `app_config.current_schema_version` **not** bumped (bump to 20 with the build that ships this). |
| `meal_logging` | `MealLogSource.plan`, `MealLog.planMealId`, `SavedMeal.{icon,notes,mealTypes,batch,libraryMealId}`, `SavedMealsRepository.updateNotes` | done; every existing test green. |
| `data/vana_transport.dart` | bearer POST + NDJSON split + status→exception map (`vana_exceptions.dart`: 401 / 402 credits / 403 `ProRequiredException` / 429 `VanaRateLimitedException(retryAfterSeconds)` / offline / server) | shared by chat, action client and `ai_coach` |
| `data/vana_chat_repository.dart` | `streamChat({message, conversationId, kind, opener, anchorDate})` → `VanaChatResponse{conversationId, kind, events}`; `fetchConversations(kind)`, `fetchMessages` (`parts` first, `content + metadata.ui_parts` fallback), `createConversation(kind)` | `ai_coach_chat_repository` delegates its transport here (`functionName: 'jade-chat'`) and keeps its API + own part parser |
| `data/vana_action_client.dart` | `run(UiAction)` → `VanaActionResult{parts, extras}` + typed extras (`plan`, `home`, `mealDetail`, `recentMeals`, `memories`, `vote`, `notes`, `logId`) | done |
| `data/meal_library_remote_data_source.dart` | `search_meals` (all params incl. `p_kind`, `p_include_disliked`), `library_pair_support`, `set_meal_feedback`, `getMeal`/`recentMeals` via actions; `rowToMealRef` + `attributionShort` ports | done |
| `data/meal_plan_repository.dart` (+ `meal_plan_remote.dart` seam) | `SyncableRepository('meal_plans')`; `watchActivePlan` (join watch; confirmed wins, else newest draft); local-first `setServings/removeMeal/setSession/addComment/toggleShopping/setDaySlot`; `uploadDirtyRecords` replays; `syncFromRemote`; `applyServerPlan` | done |
| `data/user_memory_repository.dart` | `SyncableRepository('user_memories')`; `getSetting/setSetting/watchSettings/watchMemories/deleteMemory/applyServerMemory`; upload upsert `onConflict:'id'` with setting-row id reuse | done |
| Sync registration | `sync_dependency_graph.dart` (`meal_plans: [users, saved_meals, meal_logs]`, `user_memories: [users]`), `sync_coordinator._repositoryFor` + roster, `settings_controller._uploadDirtyBeforeLogout` (every `UploadResult` checked) | done |
| `application/` | `meal_plan_controller` (keepAlive), `plan_day_controller`, `meal_catalog_controller`, `meal_detail_controller` (keepAlive family), `shopping_list_controller`, `vana_chat_controller` (family `kind` + `conversationId`), `vana_conversations_controller`, `vana_settings_controller`, `cooking_session_controller`, `home_service.dart` (`HomeService` + `HomeController`), `meal_ref_mapping.dart`, re-exports `plan_coverage_service.dart` / `meal_icon_classifier.dart` | done; `lib/shared/services/connectivity_checker.dart` is the offline seam |

### Deviations from the spec above (and why)
- **Drift is v20, not v19.** Phase 3 took v19 for `user_entitlements`; §2 below still says v19.
- **Week starts on Sunday.** The server's `weekStartFor` (`_shared/vana/env.ts`) and the fixtures use a
  Sunday-start week; `domain/week_start.dart` ports that. The `MealPlan.weekStart` doc comment says Monday —
  the comment is wrong, the code follows the server.
- **`streamChat` returns `VanaChatResponse`, not a bare `Stream`.** The `x-conversation-id` header must
  reach the caller and `VanaStreamEvent` is sealed in the domain, so the id rides alongside the stream.
- **Upload replay for `plan_meals` edits.** Removals → `plan_remove_meal`; servings → `plan_set_servings`;
  the fields with no RPC (`session`, `comments`, `swaps_applied`) → an RLS-scoped `UPDATE plan_meals … WHERE id`.
  `meal_plans.shopping` / `days` → `UPDATE meal_plans … WHERE id` (not an upsert: plans are only created
  server-side, and an upsert would carry `status`). After a successful replay the controller re-reads the plan
  (`get_plan`) so server-derived fields (`shopping`, coverage) land locally — the RPCs do not rebuild them.
- **`plan_meals.is_deleted` is a local-only tombstone** (the server hard-deletes); the row is dropped after
  `plan_remove_meal` succeeds.
- **`MealPlanController` remote-ack ops do not put the notifier into `AsyncLoading`.** The Drift watch owns the
  data state; `AsyncValue.guard` captures the action's outcome, a failure restores the previous plan and the
  error is **rethrown** so the screen can gate navigation (and show `MealvanaSnackbar`) on the ack. Offline →
  `NeedsConnectionException(operation)` before any request; pending local edits are flushed first.
- **`batch` parts are never appended to a message** — they update `VanaChatState.draftPlan` and are folded into
  `MealPlanController.applyServerPlan`. History rows have them stripped on load.
- **Local Recents skip name-only logs** (the server's `recent_meals` does the library name match); when online
  the server list replaces the local one.
- **Cooking-mode timers tick per second** (deterministic under `fakeAsync`); the presentation layer owns
  `wakelock_plus`, notifications and vibration — the controller exposes `wakeLockWanted` and `ringing`.
- **`createConversation`** inserts into `vana_conversations` directly (owner RLS `Users manage own vana
  conversations` is FOR ALL); the opener then streams against that id.

### What 4c (presentation) needs to know
- Strings: controllers carry **no user-facing copy**. Map `VanaChatErrorKind`, `NeedsConnectionException`,
  `ProRequiredException` (→ `/pro`), `VanaRateLimitedException.retryAfterSeconds`, and the `MealRef.why` /
  `attribution` server strings through `ContentKeys` (§6).
- Remote-ack methods on `MealPlanController` **throw**; wrap them in try/catch at the call site. Local-first
  methods return normally and the watch stream updates the state.
- `mealPlanControllerProvider` is `keepAlive`; `mealDetailControllerProvider(id)` too (survives a network blip).
  `vanaChatControllerProvider(kind: …, conversationId: …)` — pass `null` for a new planning chat, then
  `loadOpener()`; the state's `conversationId` fills in from the response header.
- `HomeController(date)` returns `null` offline — render from `mealPlanControllerProvider` alone.
- `CookingSessionState.ringing` lists timers that hit zero; fire the alarm, then `acknowledgeTimer`.
- `ShoppingListController.shareText()` returns the body only; the title is a content key.
- Backend follow-ups (none required for 4c): `plan_set_servings` does not rebuild `shopping` (documented in
  `docs/database/meal-planning-rpcs.md`); the client compensates with a `get_plan` re-read.


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

## 2. Drift v19 (on top of develop's v18) — *shipped as v20; see Status*
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
