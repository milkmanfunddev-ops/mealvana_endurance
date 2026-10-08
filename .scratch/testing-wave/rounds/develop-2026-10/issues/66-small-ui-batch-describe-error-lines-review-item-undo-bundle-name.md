# 66: Small UI batch: Describe's error lines wrap, a removed Review item has Undo, Back asks, the iOS bundle name

**Status:** in-progress (wave 6, 2026-10-08) (round develop-2026-10, fix wave 6)
**Labels:** fix, round:develop-2026-10, area:meal-logging, area:ios
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing in code. Shares `log_meal_screen.dart` with 60 (see Overlaps).
**Next:** `/testing-wave develop-2026-10` (fix wave 6)
**Model:** opus

**What to build:** Three small fixes from wave 5. Describe's field errors are cut to one line with an ellipsis (49-002). A swiped-away Review & Log item is gone with no undo, and Back from Review drops every edit without asking (49-003, the retest of 31-006). The iOS web-auth prompt names the app "mealvana_endurance" (50-008). Lee (2026-10-08): "small UI batch: Describe error lines wrap; a removed Review item gets a 3 s Undo and Back with edits asks; CFBundleName = Mealvana in both flavours". Line numbers are from code at `f8dd9171`.

1. **Describe's field errors wrap to three lines (49-002).** The Describe tab (`_AiTab`, `lib/features/meal_logging/presentation/screens/log_meal_screen.dart:1719-…`) has one `TextFormField` (`:2127-2152`). Its `InputDecoration` (`:2134-2140`) sets no `errorMaxLines`, and no theme sets one (grep of `lib/` finds none), so Flutter shows one line and ellipsises the rest. Both lines run through that field: the too-short validator (`:2143-2151`, `meal_log.describe.too_short`, "Add a bit more: at least {n} characters, like what you ate and how much.") and the not-food error (`forceErrorText: _notFoodError`, `:2141`, set at `:1938-1940` from `meal_log.describe.not_food`). Add `errorMaxLines: 3` to that `InputDecoration`; it stays `const`. On run 49's 402 pt iPhone 17 Pro the too-short line needs two lines.
2. **A removed Review item gets a 3 s "Item removed" with Undo, restored at its index (49-003).** Review & Log (`lib/features/meal_logging/presentation/screens/meal_review_screen.dart`) mounts the shared `MealComponentEditor` (`:232-237`). A left-to-right swipe calls `_deleteItem` (`lib/features/meal_logging/presentation/widgets/meal_component_editor.dart:71-77`, from `confirmDismiss`, `:180-188`), which removes the item and its row id (`_rowIds`, `:46-53`) at once. Edit Meal (`edit_meal_log_screen.dart:715`) and Build a Meal (`build_meal_screen.dart:381`) mount the same editor; the ruling names Review only, so the Undo is opt-in.
   - Add an optional `final ({String removed, String undo})? removeUndoLabels;` to `MealComponentEditor` (`:17-22`). When it is null, `_deleteItem` behaves as today. When set, `_deleteItem` keeps the removed component, its row id and its index, removes as today, then (like the Timeline's meal Undo, `macro_dashboard_screen.dart:1339-1351`) clears the current snackbar and calls `MealvanaSnackbar.showInfo(context, labels.removed, actionLabel: labels.undo, onAction: …)`. `showInfo` defaults to 3 s and `persist: false` (`lib/shared/widgets/kyle_design/feedback/mealvana_snackbar.dart:100-119`), so the Undo bar times out although it has an action (`:221-227`). `onAction`: if `!mounted` return; insert the component and its row id back at `min(index, _items.length)`; `widget.onComponentsChanged(List.unmodifiable(_items))`. Reusing the row id keeps the `Dismissible` key unique (`:39-46`).
   - Review passes `removeUndoLabels: (removed: content.getValue(ContentKeys.mealLogReviewItemRemoved), undo: content.getValue(ContentKeys.mealLogActionsUndo))`. `meal_log_actions.undo` "Undo" already exists (`lib/features/content/domain/content_keys.dart:306`, `assets/config/content_defaults.json:385`).
   - When Review leaves (a logged meal pops, `meal_review_screen.dart:153-162`, or Discard in step 3), hide the current snackbar so an Undo cannot act on a gone screen: take `ScaffoldMessenger.of(context)` in `didChangeDependencies` (`:66-92`) and call `hideCurrentSnackBar()` in `dispose` (`:94-98`).
3. **Back from Review with edits asks "Discard changes?" (49-003).** Review has no back guard today: its `AppBar` (`:191-195`) uses the default back button, and a Back drops the rename, swaps and removals (run 49: Back, then Review again reopened the original analysis). Copy Edit Meal's guard (`edit_meal_log_screen.dart:520-567`, `PopScope` `:579-584`, back button through `maybePop` `:591-593`) without its Save action, since Log this meal is Review's save:
   - `bool _hasEdits()`: the trimmed name differs from `_result!.name` (`:84`), or the components differ from the analysis's (`_result!.items.map(_itemToComponent)`, `:88`), compared as Edit Meal does (`jsonEncode(components.map((c) => c.toJson()))`, `edit_meal_log_screen.dart:498-499`). This covers a rename, a swap (`:116-128`), a removal and an Edit Item change. A removal that was undone compares equal again and does not ask.
   - Wrap the `Scaffold` (`meal_review_screen.dart:189`) in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop))`. No edits: `Navigator.of(context).pop()` at once. Edits: an `AlertDialog` with title, body and two actions, Keep editing (stay) and Discard (pop with no result, so Describe stays on its text and shows Review again, ticket 45). Set the `AppBar`'s `leading` to `CustomAppBarBackButton(onPressed: () => Navigator.of(context).maybePop())` as Edit Meal does, so the app-bar Back runs the guard. The logged-meal path pops with `navigator.pop(true)` (`:158-159`), which `PopScope` does not block.
   - Edit Meal's dialog words are hardcoded (`edit_meal_log_screen.dart:526-537`), so there is no Edit Meal key to reuse. New keys under `meal_log.review`, beside `name_required` (`content_keys.dart:52-56`, `content_defaults.json:374-376`), using Edit Meal's wording where it fits: `discard_title` "Discard changes?", `discard_body` "Your edits to this meal will be lost.", `discard` "Discard", `keep_editing` "Keep editing", and step 2's `item_removed` "Item removed". Edit Meal's own dialog is not changed here.
4. **`CFBundleName` → "Mealvana" (50-008).** `ios/Runner/Info.plist:17-18` holds the literal `mealvana_endurance`; iOS uses it in the `ASWebAuthenticationSession` prompt ("“mealvana_endurance” Wants to Use “vdoto2.com” to Sign In"). Both flavours build from this one plist (the flavour xcconfigs set only `PRODUCT_BUNDLE_IDENTIFIER`, `BUNDLE_DISPLAY_NAME` and the icon: `ios/Flutter/{dev,prod}-{Debug,Profile,Release}.xcconfig` and `ios/{dev,prod}-*.xcconfig`, both sets referenced by `ios/Runner.xcodeproj/project.pbxproj:64-75`), so one change covers dev and prod. Set it to `Mealvana`. `CFBundleDisplayName` (`Info.plist:9-10`, `$(BUNDLE_DISPLAY_NAME)`) stays, so the home-screen label does not change.
   - Nothing reads `CFBundleName`: the Sentry release is a literal `mealvana_endurance@<version>+<build>` in `lib/shared/core/bootstrap/bootstrap.dart:128-129` and `codemagic.yaml:135`, built from `PackageInfo.version`/`buildNumber`, not the name; no code reads `PackageInfo.appName` (grep); Patrol's `app_name` is `Mealvana Endurance` (`pubspec.yaml:300-301`), the display name, not the bundle name; `pubspec.yaml:1` `name: mealvana_endurance` is the Dart package. `ios/RunnerUITests/Info.plist:13-14` (`$(PRODUCT_NAME)`) belongs to the UI-test bundle and is not touched. Android (`android:label="@string/app_name"`, `AndroidManifest.xml:26`) and the web entry (`lib/main_web.dart`) are not touched.

**Findings:** 49-002, 49-003, 50-008.

**Decisions:**
- The Undo is opt-in on the shared editor: Edit Meal already has an unsaved-changes guard with Save, and Build a Meal has its own discard guard (`build_meal.discard_*`). Turning Undo on there is a later ruling, not this ticket.
- Only the latest removal can be undone: a second swipe clears the first bar, as the Timeline does (`macro_dashboard_screen.dart:1342`).
- Review's guard has two actions, not Edit Meal's three: Review saves only through Log this meal, which also names the meal and checks it (ticket 45's empty-name rule).
- The literal "Mealvana" is the same in both flavours, as ruled. The dev build's prompt then reads "Mealvana", not "Endurance Dev".

**Questions for Lee.**
1. Does changing only the meal type (the slot chips, `meal_review_screen.dart:223-226`) count as an edit that asks on Back? The ruling lists name and items. Recommended: no; a slot is one tap to set again.
2. (Fix agent, 2026-10-08.) On a phone where Log this meal sits at the bottom of the screen, the floating "Item removed" bar covers the button for its 3 s; a tap there lands on the bar, not the button (seen in the widget test at 390 × 844). Is that acceptable for a 3 s bar, or should Review lift the bar above the button? Recommended: accept; the bar is short-lived and Undo is the likelier tap right after a swipe.

**Touches:** lib/features/meal_logging/presentation/screens/log_meal_screen.dart, lib/features/meal_logging/presentation/screens/meal_review_screen.dart, lib/features/meal_logging/presentation/widgets/meal_component_editor.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json, ios/Runner/Info.plist, test/features/meal_logging/describe_error_lines_wrap_test.dart (new), test/features/meal_logging/review_remove_undo_and_discard_test.dart (new), test/shared/ios_bundle_name_test.dart (new). 9 files. No annotated file changes, no codegen, no Drift change, no edge function.

**Overlaps:** 60 edits `log_meal_screen.dart` (`_pickPhoto`, `:1978-2019`; this ticket edits the `InputDecoration` at `:2134-2140`): one agent takes both, or 60 runs after 66 merges. `content_keys.dart`/`content_defaults.json`: new keys under `meal_log.review` only; 55–57 and 59 do not list either file (checked at drafting). The `meal_component_editor_*_test.dart` files (duplicate key, quantity, tap) exercise the editor with no labels and must stay green.

Deploy after merge: nothing to deploy. Item 4 needs an app build to show; the wave-7 rebuild carries it.

- [x] Widget (`describe_error_lines_wrap_test.dart`, on the `test/features/meal_logging/describe_not_food_test.dart` harness, real `LogMealScreen` → Describe, view set to 402 × 874 logical pixels): type "egg", tap Analyze; the error `Text` shows the whole `too_short` line from content with `n` 5, its `maxLines` is 3 and its `RenderParagraph.didExceedMaxLines` is false; `invoke` was never called. The not-food case (the `FunctionException` 422 from `describe_not_food_test.dart`) shows its whole line the same way.
- [x] Widget (`review_remove_undo_and_discard_test.dart`, on the `test/features/meal_logging/review_empty_name_test.dart` harness: real `MealReviewScreen` pushed with constructor params over a host route, real `MealLogController`, in-memory Drift): three items; swipe the second left to right → "Item removed" with Undo shows and the total drops; tap Undo → the item is back second and the total is restored. Swipe again and pump 3 s → the bar is gone and the item stays removed.
- [x] Same file: rename, then tap the app-bar Back → "Discard changes?" with Keep editing and Discard; Keep editing → still on Review with the new name; Discard → the route pops with `null` (the host's `push` future completes null). With no edits, Back pops at once with no dialog. Remove then Undo, then Back → no dialog. Log this meal after edits still pops `true` with no dialog, and a `meal_logs` row is written.
- [x] Unit (`test/shared/ios_bundle_name_test.dart`): read `ios/Runner/Info.plist` as text; the string after `<key>CFBundleName</key>` is `Mealvana`, and `CFBundleDisplayName` is still `$(BUNDLE_DISPLAY_NAME)`.
- [x] `flutter analyze` clean on touched files.
- [x] Before committing, `grep -rl` under `test/` for every changed class and method (`MealComponentEditor`, `MealReviewScreen`, `LogMealScreen`, `ContentKeys`, the `meal_log` defaults) and run every file it names, not only this list (IMPROVEMENTS #116): the editor's existing tests, `describe_back_keeps_analysis_test.dart`, `review_empty_name_test.dart`, `ai_note_survives_the_save_test.dart`, `meal_swap_test.dart`, and any content-defaults or content-keys guard test.
- [x] No new Report helper or silent catch is expected. If one is added, it goes into `test/shared/source_guard/source_guard.dart`'s `reportCalls` or a reasoned `allow_list.md` entry in the same commit, and `test/shared/source_guard/` runs (#117).
- [x] No expected failure is written into notifier state (#118); this ticket changes no notifier.
- [x] Async paths, written down in Fix notes: Undo tapped after Review closed (the bar is hidden in `dispose`; `onAction` also checks `mounted`); two swipes inside 3 s (the second clears the first bar; only the second can be undone); Back pressed twice while the dialog is open (the first `maybePop` holds the dialog; the second is absorbed by the dialog route); the dialog open while a swap result arrives (`_swapItem` checks `mounted` and applies, `meal_component_editor.dart:79-86`; Discard still drops it).
- [x] Codegen: none expected; unfiltered if an annotated file's generated part changes.
- [ ] Retest on a simulator in wave 7 retest ticket 68 (meal logging): check 4 (the short-input line shows whole, wrapped), check 5 (the not-food line whole), check 9 (a swiped Review item shows Undo and Undo restores the item and total; Back after a rename asks Discard). The bundle-name half (50-008) is read on V.O2 Connect by whichever wave-7 run opens it (ticket 69 owns Connected Apps): the prompt reads "“Mealvana” Wants to Use “vdoto2.com” to Sign In".

**Rulings (Lee, 2026-10-08, after drafting).**
- Changing only the meal type does not ask on Back.


Next: /testing-wave develop-2026-10 (fix wave 6)

## Fix notes

**Branch** `testing-wave/develop-2026-10/66`, code commit `02a71059` (base `876ca27e`).

**What changed.**
1. `lib/features/meal_logging/presentation/screens/log_meal_screen.dart`: `errorMaxLines: 3` on the Describe field's `InputDecoration` (still `const`). Only that hunk; `_pickPhoto` is untouched for ticket 60.
2. `lib/features/meal_logging/presentation/widgets/meal_component_editor.dart`: optional `removeUndoLabels` (`({String removed, String undo})?`). Null keeps today's remove. Set: `_deleteItem` keeps the component, its row id and index, removes, clears the messenger's bars, then `MealvanaSnackbar.showInfo(removed, actionLabel: undo, onAction: …)` (3 s, `persist: false`). `onAction` returns if unmounted, else re-inserts both at `min(index, _items.length)` and calls `onComponentsChanged`.
3. `lib/features/meal_logging/presentation/screens/meal_review_screen.dart`: passes the labels (`meal_log.review.item_removed`, `meal_log_actions.undo`); takes `ScaffoldMessenger.maybeOf` in `didChangeDependencies` and calls `hideCurrentSnackBar()` in `dispose`; `_hasEdits()` (trimmed name vs `_result.name`, components JSON vs the analysis's) ignoring the slot per Lee's ruling; `PopScope(canPop: false)` with `_onPopInvoked`: no edits pops at once, edits show an `AlertDialog` (Keep editing / Discard, Discard pops with no result); app-bar `leading` is `CustomAppBarBackButton(onPressed: maybePop)`. Log this meal still pops `true` through the navigator.
4. `lib/features/content/domain/content_keys.dart` + `assets/config/content_defaults.json`: `meal_log.review.{item_removed, discard_title, discard_body, discard, keep_editing}` only, beside `name_required`.
5. `ios/Runner/Info.plist`: `CFBundleName` `Mealvana`. Nothing else under `ios/`.
6. Tests (new): `test/features/meal_logging/describe_error_lines_wrap_test.dart` (2), `test/features/meal_logging/review_remove_undo_and_discard_test.dart` (7), `test/shared/ios_bundle_name_test.dart` (2).

**Async paths.**
- Undo tapped after Review closed: Review's `dispose` hides the current bar, and `onAction` checks `mounted` first. Tested on the Discard path: the bar is gone after the pop (fails with the `dispose` line removed).
- Two swipes inside 3 s: the second `clearSnackBars()` drops the first bar, so only the latest removal can be undone; the first stays removed.
- Undo after a swap or another edit moved things: the item goes back at `min(index, length)`, so it never throws; with its own row id the `Dismissible` key stays unique.
- Back pressed twice while the dialog is open: the dialog route is on top, so the second Back pops the dialog (= Keep editing), not Review. `CustomAppBarBackButton` also debounces 500 ms.
- Swap result arriving while the dialog is open: `_swapItem` checks `mounted` and applies; Discard still drops it.
- Log this meal pressed twice: unchanged from before (button disabled while `AsyncLoading`).
- Hiding in `dispose` hides whatever bar is current when Review leaves. Describe shows no bar after Review pops, so nothing of another screen's is lost today.

**Tests run.**
- New files: 2 + 7 + 2, all pass. The wrap test fails (maxLines null) with `errorMaxLines` removed.
- #116: `grep -rlE "MealComponentEditor|MealReviewScreen|LogMealScreen|_deleteItem|removeUndoLabels|content_defaults|meal_log\.review|mealLogReview|Info\.plist|ContentKeys" test` plus `content_defaults_resolve_without_caller_test.dart` and `edit_meal_log_guard_test.dart`: 29 files, +151, all passed (includes the three `meal_component_editor_*` tests, `describe_back_keeps_analysis`, `review_empty_name`, `ai_note_survives_the_save`, `meal_swap`, `describe_not_food`).
- `flutter analyze` on the four lib files and three test files: no issues.
- No catch or Report helper added, so `test/shared/source_guard/` was not needed. No codegen (no annotated file touched).

**For the lead.**
- The "Log this meal after edits" test lets the Undo bar time out before tapping, because the floating bar covers the button at 390 × 844 (Question 2).
- Retest box stays open for wave 7 (ticket 68 checks 4, 5, 9; the V.O2 prompt needs the rebuild).

