> Resumed 2026-09-23 and finished: results in `results.md`, notes in `notes.md`. Kept as the pause record.

# Ticket 03, run w3-20260923T1942Z: paused

Paused 2026-09-23 at the coordinator's request (Lee had to leave). Device: pool simulator
wave-pool-1 (3481E23B-…), iOS 26.2, dev flavor, integration-test account. Suite runs use
`patrol test` with every target from `node scripts/patrol-targets.mjs targets` in one invocation.

## Results so far

| Flow | Result |
|------|--------|
| activities_crud | pass (attempt 2; attempt 1 failed at the notification prompt, see below) |
| ai_credits_balance | pass |
| auth | **fails** both attempts: neither the tabs shell nor the welcome screen within 90 s, then the test burns its 300 s timeout. Not diagnosed yet |
| barcode_scanner_entry | pass |
| brick_plan | pass |
| energy_breakdown | pass |
| event_checklist_carbload | pass |
| events_crud | pass |
| formula_create_pin | pass |
| formula_pin_conflict | not run yet |
| formula_pin | not run yet |
| fueling_window_persistence | not run yet |
| integrations_connect (3 cases) | not run yet (expect a self-skip on a signed-in sim: it needs the welcome screen) |
| learn | not run yet |
| macro_dashboard | not run yet |
| meal_card_interaction | not run yet |
| meal_log_build | not run yet |
| pro_gate | not run yet |
| recommendation_stacking (2 cases) | not run yet |
| settings_persist | not run yet |
| settings_sweep | not run yet |
| patrol_smoke | not run yet |
| onboarding_signup (clean-install) | not run yet |
| account_delete (clean-install) | not run yet |
| google_login (interactive-oauth) | not run yet (expected self-skip on iOS) |
| ai_coach_chat (ai-spend) | not run yet; original version to be run once first |
| meal_plan_build (ai-spend) | not run yet; spend `cost.mjs spend 3 plan 03` first |

No Findings written yet.

## What the run has found so far (to become Findings / notes)

- Attempt 1 (`patrol-suite-attempt1.log`, `attempt1-notification-prompt-over-splash.png`): a
  fresh install shows iOS's "Would Like to Send You Notifications" alert at startup
  (`NotificationService.initialize` → OneSignal `requestPermission`, deferred startup step 3).
  While it was up, activities_crud's login never reached the shell and auth never reached the
  welcome screen. Handled in test code (below); consider an idea/followup Finding about the
  prompt appearing on first launch before any context.
- The integration-test account (37129f7e-…) has a dev `user_entitlements` row of
  `period_type eval` that ended 2026-09-16, and RevenueCat has no active entitlement for it
  (`revenuecat-test-account-active-entitlements.json`). It is not admin. Yet flows after the
  first reach the tabs shell. Check whether the Gate lets a lapsed account in (possible bug, or
  the cloned simulator's anonymous RevenueCat customer noted in runs/02/notes.md), and whether
  auth's failure is this account landing on the paywall.

## Committed on the branch before the pause

- `scripts/patrol-targets.mjs` + `test/scripts/patrol-targets.test.mjs` (10 node tests green),
  `integration_test/runner_exclusions.json`, `// runner-cases: 3` in integrations_connect.
- `.github/workflows/tests-selfhosted.yml`: targets and expected count derived from the script;
  install note names patrol 4.10.0 / patrol_cli 4.8.0.
- `integration_test/README.md`, `SETUP_COMPLETE.md` (superseded banner), docs/test bug lists
  marked superseded by the Findings folder, docs/test/README.md.

## In the WIP commit (the pause commit)

- `integration_test/helpers/flow_launcher.dart`: `launchApp($)` now takes the tester and calls
  `answerStartupPermissionPrompt($)`, which waits up to 10 s once per run for a native
  permission dialog and taps Don't Allow.
- Every flow and `patrol_smoke_test.dart`: `launchApp()` → `launchApp($)`.
- `integration_test/README.md`: the helper row mentions the prompt.
- `ai_coach_chat_flow_test.dart` is the ORIGINAL (unchanged). A rewrite for the Vana general
  chat (`/jade` redirects to `/vana?mode=general`; keys `meal_planning.chat_input`,
  `chat_send`, `chat_message_<n>`) is parked at `runs/03/ai_coach_chat_rewrite.dart.txt`; copy it in after running the
  original once (expected: self-skip, "ai_coach.chat_screen" never appears).

## Next step to resume

1. `LOCK claim slot testing-wave-03`, `SYNC simulator claim testing-wave-03 --wait 90`.
2. Diagnose auth: run it alone (`--target integration_test/flows/auth_flow_test.dart`) with a
   `simctl io screenshot` at ~60 s to see what screen it sits on; read the failure message in
   the xcresult (`build/ios_results_1790193905166.xcresult` holds attempt 2).
3. Build lock, then run the remaining targets in one invocation (formula_pin_conflict onward,
   plus patrol_smoke), release the build lock once "Completed building" prints.
4. Uninstall the app, run onboarding_signup alone; uninstall again, run account_delete alone;
   run google_login; run original ai_coach_chat, then the rewrite (spend `logging`); spend
   `plan` and run meal_plan_build.
5. Write Findings, `results.md` (per-flow table), `notes.md` (look-around, console lines), tick
   the ticket's criteria, token-scan and `git add -f` the logs, release sim and locks.
