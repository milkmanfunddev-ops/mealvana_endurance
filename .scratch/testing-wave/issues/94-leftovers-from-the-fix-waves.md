# 94: Leftovers from the fix waves

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Seven small fixes that reviews and ticket notes in waves 22-24 left behind, done as one batched list:

1. The Swap screen asks `search_meals` for 20 meals and then drops the blank-number ones, so it can show a short list. Ask for more, or filter blank-number meals out on the server (ticket 74 note; 61-001).
2. The plan reveal's "Connect now" nudge still shows after "I don't use training plan apps" (`plan_reveal_screen.dart:243`). Use the same `declinedTrainingApps` guard as ticket 80.
3. Emailed-code screens submit on their own when the sixth digit is entered (32-007 steps 2-3; ticket 81 added only the autofill hint).
4. `RevenueCatService`: `_configureSettled` completes after a FAILED first configure, so a later `logIn` skips instead of waiting for the retry (ticket 85 review note). Settle only on success, or make `logIn` wait for the retry.
5. The Settings "Profile & Preferences" tile is a hardcoded string (`settings_screen.dart:817`). Move it to the content system.
6. The iOS Speech Recognition and Microphone purpose strings in `ios/Runner/Info.plist` still talk about voice notes on the nutrition plan. Say it is for talking to Vana (ticket 79 note).
7. Add two scenarios to the Vana evals corpus (`evals/vana/scenarios/v1.json`, shape as its other entries; do not run the harness). 12-005: the athlete names a "long ride" that the calendar does not hold. 14-005: New meal plan when last week had a confirmed plan (the opener must not debrief it).

**Findings:** 61-001, 04-008, 32-007, 09-013, 31-014, 09-004 (leftover halves), 12-005, 14-005. A retest closes them (ticket 100 for 32-007); this ticket does not.

**Decisions:** none; each restores behaviour no decision disputes.

**Touches:** lib/features/meal_planning/ (the Swap screen and its search call; supabase/functions `search_meals` if filtered server-side), lib/features/onboarding/presentation/screens/plan_reveal_screen.dart, the emailed-code screens under lib/features/auth/, lib/features/ai_credits/data/revenuecat_service.dart, lib/features/settings/presentation/screens/settings_screen.dart, assets/config/content_defaults.json, ios/Runner/Info.plist, evals/vana/scenarios/v1.json

- [ ] A test for each of items 1-5 (item 6 is a plist string, item 7 is data).
- [ ] codegen if annotations changed, `flutter analyze` clean on touched files, deno tests for any touched function. The suite: wave lead.

Next: /implement-lee testing-wave
