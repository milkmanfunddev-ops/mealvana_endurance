# 129: Offline and a slow network say so, with a retry

**Status:** in-progress (wave 33, 2026-09-25)
**Blocked by:** 127 (both change the Review sheet, the chat screen and its controller).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Eight places in meal planning where a network failure shows nothing, the wrong words, or a screen that looks like something else, from wave 29. The rule for all of them: a failed read says it could not load and offers Retry; a failed write says it needs a connection (`mpNeedsConnection` / `mpVanaOffline`) and leaves the screen as it was; nothing waits forever.
1. **New meal plan offline (88-011).** The planning chat shows an empty "New meal plan" with no message; `_handleError` shows a snackbar and clears the error at once. Keep the error in state and show a line with Retry, like the Ask Vana sheet (`vana_companion.dart` ~681-720). Browse from its plus menu either works or says why not.
2. **Conversation list and an opened conversation offline (88-012).** The list spins 35 s and more (Riverpod's default retry keeps it loading); show the error branch with Retry within a few seconds. An opened conversation whose history failed shows "couldn't load this conversation" with Retry, never the empty new-plan screen, and loads when Retry is tapped after the network returns.
3. **Browse Add offline (88-013).** `VanaOfflineException` falls into `on Exception` and shows "Something went wrong. Try again." Map it to the connection message, once, in `_remoteAck` or at each of the three call sites (`vana_browse_screen.dart`, `meal_detail_screen.dart _addToPlan`, `vana_chat_screen.dart _pickMeal`).
4. **Confirm offline (88-015).** `onConfirm` returns false and `_ReviewSheet._confirm` shows nothing. The sheet shows the failure (connection or server) and keeps the draft.
5. **Ask Vana send offline (88-022).** The sent text vanishes. Keep the athlete's message visible with a failed state (or put the text back in the composer), and Retry resends that text.
6. **Shopping offline after the list was deleted (89-001).** `shopping_tab.dart:50` takes the first-run empty state ("Confirm a meal plan…") before the offline notice at line 86. Offline, the tab says it is offline and never tells an athlete with a confirmed plan to confirm one. Share with nothing to share says why (`shopping_share_button.dart:26` returns silently).
7. **Earlier plan view hangs (89-005).** `VanaTransport.postJson` has no timeout, so a request stuck before sending spins for good. Add a timeout mapped to `VanaOfflineException` (long actions such as `confirm_plan` and chat turns get a longer one), and the earlier plan view shows an error with Retry.
8. **Previous plans offline (89-011).** Stop the 35-40 s retry spin, and make the failed text's promise true: add a RefreshIndicator, or a Retry button with the `previous_plans_failed` text reworded.

**Findings:** 88-011, 88-012, 88-013, 88-015, 88-022, 89-001, 89-005, 89-011.

**Decisions:** none.

**Touches:** lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/application/vana_chat_controller.dart, lib/features/meal_planning/application/vana_conversations_controller.dart, lib/features/meal_planning/presentation/screens/vana_conversations_screen.dart, lib/features/meal_planning/presentation/screens/vana_browse_screen.dart, lib/features/meal_planning/presentation/screens/meal_detail_screen.dart, lib/features/meal_planning/application/meal_plan_controller.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/presentation/widgets/vana_companion.dart, lib/features/meal_planning/presentation/screens/shopping_tab.dart, lib/features/meal_planning/presentation/widgets/shopping_share_button.dart, lib/features/meal_planning/data/vana_transport.dart, lib/features/meal_planning/application/previous_plans.dart, lib/features/meal_planning/presentation/screens/previous_plan_screen.dart, lib/features/meal_planning/presentation/widgets/previous_plans_sheet.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

- [ ] Controller tests through the real notifiers: a failed opener, a failed history read, and a failed conversations read each end in an error state with a retry that re-runs the call.
- [ ] Widget tests: Browse Add and Confirm under `VanaOfflineException` show the connection message; the Ask Vana sheet keeps the failed text; the Shopping tab offline with an empty mirror shows the offline notice, not the first-run state.
- [ ] Transport test: a request that never answers ends in `VanaOfflineException` after the timeout.
- [ ] No hardcoded strings; `flutter analyze` clean on touched files.

Next: /implement-lee testing-wave
