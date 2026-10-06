# 23: Food-prefs null check

**What to build:** MEALVANA-ENDURANCE-CC: null check operator on a null value in the likes/dislikes row. Fix and test.

**Blocked by:** 10 Contract

**Status:** done

- [x] Widget test reproduces and passes
- [ ] Issue resolved in Sentry (lead, after merge)

## Root cause

**MEALVANA-ENDURANCE-CC** (1 event, OnePlus8Pro, Android 11, 1.27.0+141, 2026-09-21). Frames:
`_FoodPreferencesScreenState._loadFoods` (food_preferences_screen.dart:307 in that build) →
`State.setState` (framework.dart:1221). The `!` is not in our code. In a release build
`setState` ends in `_element!.markNeedsBuild()`, and `_element` is null once the State is
disposed. The breadcrumbs show the sequence. 07.217 push `settings-food-preferences`. 07.587 user
foods synced. 08.178 the user taps back (`didPop`). 08.273 the last catalog HTTP call returns. Then
`_loadFoods` resumed after `Future.wait` and called `setState` with no `mounted` check, then
`_seedSearchController()` used `ref` on the dead widget. The catch path had the same unguarded
`setState`. "likes_dislikes_row" is only the transaction name: it was the last tapped row.

**MEALVANA-ENDURANCE-DEV-9E is a different bug.** It has 3 events, 2 users, iOS dev 1.27.1+4,
transaction `vana-browse`. Frames: `_VanaChatScreenState._scrollToBottom.<fn>` → `ScrollPosition.maxScrollExtent`
(`_maxScrollExtent!`). It is the Vana chat screen, not food preferences. A post-frame
`animateTo(position.maxScrollExtent)` runs when the controller has a client that has not been laid
out yet: the chat was pushed and `vana-browse` covered it in the same frame. `hasClients` is true
but `hasContentDimensions` is false.
`lib/features/meal_planning/presentation/screens/vana_chat_screen.dart:1033`. Not fixed here (see
Sentry resolution).

## Fix

- `lib/features/settings/presentation/screens/food_preferences_screen.dart`:
  - `_loadFoods`: after the awaits, `if (!mounted)` leaves a `report.info` breadcrumb and returns
    before `setState` and `_seedSearchController()`. The catch path's `setState` now sits inside the
    existing `mounted` check.
  - The same unguarded `setState`-after-`await` pattern is also fixed in `_saveSearchedFood`,
    `_deleteUserFood` and `_openCreateFoodScreen` (`if (!mounted) return;`).
- Test: `test/features/settings/presentation/food_preferences_screen_unmount_test.dart`. It parks
  `getPrimaryFoodsForPreferences` on a completer, disposes the screen with the ProviderScope still
  alive (as a back-pop does), completes the fetch, and asserts no exception and no `fault`.
  **Red before the fix**: "Loading food preferences failed: setState() called after dispose()" (the
  debug-mode form of the release `_element!`). Green after.
- `dart analyze` on both files: clean. `flutter test test/shared/source_guard`: green.

## Owed

Nothing for CC. DEV-9E needs its own one-line fix (guard `position.hasContentDimensions` in
`_scrollToBottom`). Its ticket and owner are the lead's call.

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-CC | resolve | Ticket 23 (<sha>): _loadFoods called setState after the user backed out mid-load (release-mode `_element!`). Now returns when unmounted; widget test covers it. |
| MEALVANA-ENDURANCE-DEV-9E | leave-open: different bug | Not the food-prefs bug. Vana chat `_scrollToBottom` reads `maxScrollExtent` before the list is laid out (covered by vana-browse). Needs a `hasContentDimensions` guard. |
