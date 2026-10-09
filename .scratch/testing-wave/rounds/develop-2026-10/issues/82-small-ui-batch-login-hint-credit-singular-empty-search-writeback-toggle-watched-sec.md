# 82: Small UI batch: Log In's own password hint, "1 Credit", empty Search says so, the write-back toggle follows the sheet, watched_sec is time played

**Status:** ready (round develop-2026-10, fix wave 8)
**Labels:** fix, round:develop-2026-10, area:auth, area:ai-credits, area:meal-logging, area:integrations, area:education
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Findings 67-004, 69-013, 68-010, 69-009, 69-007; TRIAGE.md rulings of 2026-10-09
**Blocked by:** nothing in code. Shares `content_keys.dart` and `content_defaults.json` with 81, 72 and 73 (see Overlaps).
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

Line numbers are from code at `84615131`. This is one agent's list (RUNBOOK "Fix waves" item 3, batch small work). Item 5 is the only one with real logic.

Lee, 2026-10-09: "one batch ticket, all five: own hint key for login (or none), singular 'Credit' through the content/pluralisation path, empty-search feedback, the toggle re-reads its pref after the sheet closes, watched_sec counts played time and `education_video_completed` needs real playback."

## Findings

- **67-004 · Log In's empty password field shows the sign-up hint "At least 8 characters".** Welcome → I already have an account → Log in with email, then tap Password (23:24Z, 23:27Z). Evidence: `runs/67/67-36-login-password-focus.png`, `runs/67/67-46-login2-password-focus.png`.
- **69-013 · AI Credits lists the tester pack as "1 Credits".** On a dev build, `com.milkman.mealvanaendurance:///buy-credits` shows "1 Credits | $0.99 one-time purchase" (23:44Z). Evidence: `runs/69/m01-ai-credits-signed-in.png`.
- **68-010 · Log a Meal's header Search with an empty field does nothing (retest of 50-013).** Neither the magnifier tap nor Return in the empty field does anything: no change on screen and no console line. Evidence: `runs/68/12a-empty-search-tap.png`, `runs/68/12b-empty-search-submit.png`.
- **69-009 · After Turn Off Sharing, the TrainingPeaks card's "Write fuel plan to TrainingPeaks" toggle still shows on.** Connected Apps → reconnect TrainingPeaks → the "Your fuel plan goes to your coach" sheet → Turn Off Sharing. At 23:41:01Z `flutter.tp_writeback_enabled` read 0 while the toggle stayed on (AX value 1). After reopening Connected Apps it read off. Evidence: `runs/69/k15-after-turn-off.png`, `runs/69/k16-reopened.png`, `runs/69/k19-toggle-on.png`.
- **69-007 · Scrubbing a lesson to the end without playing it sends `education_video_completed`.** Learn → lesson 1.1 (1:36), no play, the progress bar dragged to the end, Back. That sent `education_video_closed {percent_watched: 100, watched_sec: 96, duration_sec: 96}` and `education_video_completed` with the same properties (~23:36Z). Evidence: `runs/69/j04-scrubbed.png`, `runs/69/console-redacted.log`.

## Fix

1. **Log In gets its own hint key (67-004).** From code: the password field's `hintText` reads `auth.email_signup.password_hint` (`lib/features/auth/presentation/screens/email_login_screen.dart:288-291`). That key's default is "At least 8 characters" (`assets/config/content_defaults.json:281`), so the code default "Enter your password" never shows.
   - Add `static const String loginPasswordHint = 'auth.login.password_hint';` beside the `auth.login.*` keys (`lib/features/content/domain/content_keys.dart:6-9`). Add `"password_hint": "Enter your password"` to the `auth.login` block (`content_defaults.json:314-318`).
   - `email_login_screen.dart:288-291` reads `contentService.getValue(ContentKeys.loginPasswordHint)`.
   - Unchanged: Sign Up (`email_signup_screen.dart:453`), where the rule belongs, and Set New Password (`set_new_password_screen.dart:131-134`), where a new password must meet the 8-character rule. Those are the only other readers of `auth.email_signup.password_hint` (grep).
2. **"1 Credit" through the content system (69-013).** From code: the pack title is the literal `'$credits Credits'` (`lib/features/ai_credits/presentation/screens/buy_credits_screen.dart:276-281`). The balance has the same gap: `'${…} credits'` (`:227-229`) would read "1 credits".
   - The content system has no plural helper. It has `{n}` interpolation (`ContentKeys.format`, `content_keys.dart:358-367`) and the precedent of a singular/plural pair (`meal_log.serving_singular`/`serving_plural`, `content_keys.dart:48-51`, read at `log_meal_screen.dart:334-347`). Use both: four keys under `ai_credits` (`content_keys.dart:335-342`, `content_defaults.json:408-415`): `pack_title_one` "{n} Credit", `pack_title_other` "{n} Credits", `balance_one` "{n} credit", `balance_other` "{n} credits".
   - Add one top-level helper in the screen file: `String _creditsLabel(ContentService c, int n, String oneKey, String otherKey) => ContentKeys.format(c.getValue(n == 1 ? oneKey : otherKey), {'n': n});`. It gives "0 credits" for zero.
   - `_PackageList` (`:245-302`) and `_BalanceHeader` (`:210-240`) become `ConsumerWidget`s that read `contentServiceProvider`, as `_CreditsExplanation` (`:324-340`) already does. Their constructors do not change, so the call sites at `:171` and `:188-192` stay. The top-up sheet already says "1 token" (`token_top_up_sheet.dart:50-51`) and is not touched.
3. **An empty Search says what to do (68-010).** From code: `FoodSearchBar` hands every Search tap (`lib/shared/widgets/food_selection/food_search_bar.dart:113`) and every keyboard submit (`:71`) to `onSearch(controller.text)`, empty or not. Both callers' `onSearch` only unfocuses: Log a Meal (`log_meal_screen.dart:955-958`) and Build a Meal (`build_meal_screen.dart:1014-1022`). An empty query therefore does nothing visible.
   - Fix it once in the shared bar, for both screens. Add a private `void _search(BuildContext context, ContentService content)`. When `controller.text.trim().isEmpty`, it shows `MealvanaSnackbar.showInfo(context, content.getValue(ContentKeys.foodSearchEmptyQuery))` and does not call `onSearch`. Otherwise it calls `onSearch(controller.text)` as today. `:71` and `:113` both call it.
   - New key `food_search.empty_query` "Type a food or recipe to search." beside `food_search.search` (`content_keys.dart:45-47`, `content_defaults.json:367-370`).
   - The `onChanged == null` fallback (`:64-68`, `onSearch('')` to clear) is a different path and stays. Neither caller hits it, since both pass `onChanged`.
   - The callers' hardcoded `hintText` strings (`'Search anything to add...'`, `'Search foods to add...'`) are not part of this Finding and stay.
4. **The toggle re-reads its pref after the sheet closes (69-009).** From code: `TpWritebackToggleRow` reads `ref.watch(preferencesServiceProvider).tpWritebackEnabled` (`lib/features/settings/presentation/widgets/tp_writeback_toggle_row.dart:26-27`). `PreferencesService` is a keepAlive wrapper over SharedPreferences (`lib/shared/services/preferences_service.dart:147-151`), so the row redraws only when that provider is invalidated. The row's own switch does that (`:78-82`). `_showWritebackConsentNotice` (`lib/features/settings/presentation/screens/connected_apps_screen.dart:960-975`) writes `setTpWritebackEnabled(false)` on Turn Off Sharing (`:971-973`) but invalidates nothing.
   - After the sheet's writes (after `:974`): `if (context.mounted) ref.invalidate(preferencesServiceProvider);`. Do it whatever the choice: `ensureTpWritebackDefaultExplicit` (`:968`) may also have written. Both callers go through this one method: Settings (`_connectTrainingPeaks`, `:986`) and onboarding (`_connectTrainingPeaksOnboarding`, `:1125`).
   - The shell's migration notice (`lib/shared/widgets/tabs_screen.dart:57-90`) writes the same pref from the tabs, where no toggle row is on screen. Connected Apps reads the pref fresh when it opens, so that path is not changed.
5. **watched_sec is time played, and completed needs real playback (69-007).** From code: `_onPlaybackTick` keeps only `_maxPosition`, the furthest position the listener saw (`lib/features/education/presentation/screens/video_player_screen.dart:46-49`, `:68-74`). `_trackWatchCompleted` sends `watched_sec: _maxPosition.inSeconds` and computes `percent_watched` from it (`:98-110`), and sends completed at ≥ 90 % (`:76-77`, `:112-114`). A seek moves the position the same as playing does, so a scrub counts as watched.
   - **The rule chosen.** Played time is the sum of position steps taken while the player reports `isPlaying`, where each step is greater than 0 and at most 1 s. video_player polls the position every 100 ms while playing (`video_player-2.10.1/lib/video_player.dart:625`), so real playback moves in steps of about 100 ms (× speed). A drag moves in one jump, and a paused drag has `isPlaying` false. `watched_sec` = played seconds. `percent_watched` = played ÷ duration, clamped to 0–100. `education_video_completed` fires when `percent_watched` ≥ `completedPercent` (90, unchanged), so it needs ≥ 90 % of the duration actually played. Add `furthest_sec` (`_maxPosition.inSeconds`) to keep the old fact.
   - Fields: `Duration _played = Duration.zero; Duration? _lastTickPosition; static const Duration _maxTickStep = Duration(seconds: 1);`. In `_onPlaybackTick`, after the `_maxPosition` update: `final last = _lastTickPosition; if (value.isPlaying && last != null) { final step = value.position - last; if (step > Duration.zero && step <= _maxTickStep) _played += step; } _lastTickPosition = value.position;`.
   - In `_trackWatchCompleted`, compute `percent` from `_played` (`:98-102`), set `'watched_sec': _played.inSeconds`, and add `'furthest_sec': _maxPosition.inSeconds`. `education_video_closed` still fires on every exit with a `contentId` (`:95-96`, `:111`).
   - A rewatch can make `_played` larger than the duration. `watched_sec` reports it as played. The percent clamps at 100.

**Decisions.**
- Log In gets its own key (the ruling's first choice) with the screen's own wording, "Enter your password", which the Finding expected.
- The plural is a one/other key pair with `{n}`, not a new plural engine: the content system has neither ICU nor a plural helper, and the serving pair is the precedent.
- The empty-search fix lives in the shared `FoodSearchBar`, so Build a Meal gets it too. Both callers are listed. It also keeps this ticket out of `log_meal_screen.dart`, which 81 edits.
- `percent_watched` changes meaning from "furthest point" to "share played". Questions asks about this, because Mixpanel boards may chart it. `furthest_sec` keeps the old number.

**Concurrency and refresh.**
- Item 4: the invalidate runs after the awaited writes, so the row reads the written value. If the screen closed while the sheet was up, `context.mounted` is false and nothing runs, and the next open reads the pref fresh. Two quick connects cannot overlap: the screen disables Connect while `isConnecting`.
- Item 5: the listener runs on the UI isolate, one tick at a time, so `_played` has no concurrent writer. A retry (`_initializePlayer`, `:130-135`) disposes the old controller. The new one needs `_lastTickPosition = null` reset at the top of `_initializePlayer`, so the first tick of a fresh controller is not compared against the old one. Played time from before the retry is kept.
- Item 3: two taps on an empty Search show two info bars, and the second replaces the first (`MealvanaSnackbar` clears the current bar).

## Touches

lib/features/auth/presentation/screens/email_login_screen.dart
lib/features/ai_credits/presentation/screens/buy_credits_screen.dart
lib/shared/widgets/food_selection/food_search_bar.dart
lib/features/settings/presentation/screens/connected_apps_screen.dart
lib/features/education/presentation/screens/video_player_screen.dart
lib/features/content/domain/content_keys.dart
assets/config/content_defaults.json
test/features/auth/presentation/login_password_hint_test.dart (new)
test/features/ai_credits/buy_credits_back_and_copy_test.dart
test/shared/widgets/food_selection/food_search_bar_test.dart
test/features/settings/tp_writeback_toggle_after_sheet_test.dart (new)
test/features/education/video_player_analytics_test.dart

12 files. No annotated file changes, no codegen, no Drift change, no edge function.

**Overlaps.** `content_keys.dart` and `content_defaults.json` are also in the Touches of 81, 72 and 73. This ticket only adds keys, under `auth.login`, `ai_credits` and `food_search`; 81 adds `meal_log.describe.camera_access_off` and an `event_form` section. Under #63 these tickets run one after the other, or the lead gives the key edits to one agent. No other file is shared with 81 or 83. 83 edits `custom_app_bar_back_button.dart`, which `buy_credits_screen.dart:153` mounts but this ticket does not change.

## Tests

Seam tests per `docs/test/README.md` § Seam tests.

- [ ] Widget (`login_password_hint_test.dart`, new, on the `login_error_line_test.dart` harness with `testContentService`): the empty Password field's `InputDecoration.hintText` is the `auth.login.password_hint` default "Enter your password", not "At least 8 characters". Sign Up's password hint still reads "At least 8 characters" (pump `EmailSignupScreen` the way `test/smoke_tests/auth_misc_smoke_test.dart` does).
- [ ] Widget (`buy_credits_back_and_copy_test.dart`, new case): override `visibleCreditPackagesProvider` (`:77`) with three real RevenueCat `Package`s built as `test/features/ai_credits/application/visible_credit_packages_test.dart` builds them, with the identifiers from `kCreditsByProductId` (`mealvana_credits_test_1`, `mealvana_credits_50`, `mealvana_credits_250`; `credit_packs.dart:17-27`). The tiles read "1 Credit", "50 Credits" and "250 Credits". A wallet of 1 reads "1 credit"; a wallet of 12 (`_FakeCreditsController`, `:26-29`) reads "12 credits".
- [ ] Widget (`food_search_bar_test.dart`, new case beside `:13`): with an empty controller (and with "   "), tap the labelled Search and submit through `tester.testTextInput.receiveAction(TextInputAction.done)`. `onSearch` is never called, and the `food_search.empty_query` text shows once in a `SnackBar`. Put the bar under a `Scaffold`; the existing harness already has one. The existing "oats" case still calls `onSearch` with 'oats'.
- [ ] Widget (`tp_writeback_toggle_after_sheet_test.dart`, new, on the `connected_apps_reconnect_test.dart` harness: real `ConnectedAppsScreen`, in-memory Drift, real SharedPreferences mock values). A `ConnectTrainingController` subclass whose `connectTrainingPeaks` returns true and flips TP to connected (the seam is the controller's answer, not OAuth). Tap Connect on TrainingPeaks, then Turn Off Sharing on the sheet. Without reopening the screen, the `connected_apps.tp_writeback_toggle` `KyleSwitch` has `value == false` and the pref reads false. Keep Sharing leaves both true.
- [ ] Widget (`video_player_analytics_test.dart`, rewritten for played time): give `_FakeVideoPlatform` a settable position (`getPosition`, `:93`) and a playing flag. The video_player controller polls `getPosition` every 100 ms while playing. "Played to 91 %": `play()`, then advance the fake position 100 ms per 100 ms pump until 91 s, then close. Expect `closed {watched_sec: 91, percent_watched: 91}` and one completed with the same properties. "Left at 15 %": the same to 15 s. Expect closed only. "Scrubbed to the end, never played" (69-007): `seekTo(100 s)` with no `play()`, then close. Expect `closed {watched_sec: 0, percent_watched: 0, furthest_sec: 100}` and no completed. "Played 10 s, then dragged to the end while playing": `watched_sec` 10 and no completed. The two existing seek-based cases (`:158-179`) assumed a seek is watching and are replaced by these. The offline case (`:181-`) is unchanged.
- [ ] `flutter analyze` clean on touched files.
- [ ] #116: before committing, `grep -rl` under `test/` for `EmailLoginScreen`, `BuyCreditsScreen`, `FoodSearchBar`, `ConnectedAppsScreen`, `TpWritebackToggleRow`, `preferencesServiceProvider`, `VideoPlayerScreen`, `ContentKeys` and `content_defaults`, and run every file named (at least `login_error_line_test.dart`, `email_login_busy_test.dart`, `hint_login_lands_on_main_test.dart`, `auth_misc_smoke_test.dart`, `misc_smoke_test.dart`, `settings_smoke_test.dart`, `connected_apps_reconnect_test.dart`, `connected_apps_garmin_reauth_test.dart`, `tp_writeback_consent_golden_test.dart`, the `build_meal`/`log_meal` widget tests that pump the search bar, and `content_defaults_resolve_without_caller_test.dart`).
- [ ] #117: no new Report helper and no new catch, so `test/shared/source_guard/` is not required. If one is added, it goes into `reportCalls` or `allow_list.md` in the same commit, and `test/shared/source_guard/` runs.
- [ ] #118: no expected failure is written into notifier state.

## Deploy

None. Client only.

## Retest

Next test wave, on a simulator (rebuild):
- **67-004:** Log In with email, tap the empty Password field. The hint reads "Enter your password". Create Account's still reads "At least 8 characters".
- **69-013:** signed in on a dev build, open `com.milkman.mealvanaendurance:///buy-credits`. The tester pack reads "1 Credit"; the others "50 Credits" and "250 Credits".
- **68-010:** Log a Meal, then tap the magnifier with the field empty. The bar reads "Type a food or recipe to search." Return in the empty field gives the same. Typing "oats" still searches. The same check on Build a Meal.
- **69-009:** Connected Apps → reconnect TrainingPeaks → Turn Off Sharing. The card's "Write fuel plan to TrainingPeaks" toggle reads off at once (AX value 0), matching `flutter.tp_writeback_enabled` 0, with no reopen.
- **69-007:** Learn → lesson 1.1, drag to the end without playing, Back. `education_video_closed {watched_sec: 0, percent_watched: 0}` and no `education_video_completed`. Then play about 10 s and Back: `watched_sec` ≈ 10.

## Questions for Lee

1. `percent_watched` on `education_video_closed`/`_completed` changes from the furthest point reached to the share actually played, so it agrees with `watched_sec` and with what "completed" now means. Any Mixpanel board that charts `percent_watched` will show lower numbers from this build on. The furthest point stays as `furthest_sec`. Recommended: accept. A board that wanted "how far did they get" can switch to `furthest_sec`.

**Rulings (Lee, 2026-10-09, wave 7 close).**
- Q1: accepted: percent_watched becomes the played share, furthest_sec keeps the old meaning, education_video_completed needs 90 % played.
