# Ticket 03, run w3-20260923T1942Z: per-flow results

Each flow's last run on pool simulator wave-pool-1 (iOS 26.2, dev flavor). "fixed" = the flow was
out of date with the app and its test code was updated, then it passed. Accounts: the Patrol
account in `secrets/integration_test.env` is lapsed on dev (03-003), so from the second session on
the credentialed flows ran as the dev admin (test@test.com, active Pro), with
`--dart-define=PATROL_FAIL_ON_SKIP=true` so a skip fails instead of looking green (03-001).

| Flow | Result | Log |
|------|--------|-----|
| patrol_smoke_test | pass | patrol-suite-rest.log |
| account_delete | pass (clean install) | patrol-clean-a.log |
| activities_crud | pass | patrol-batch4.log |
| ai_coach_chat | fixed: the original self-skipped (/jade redirects to the Vana general chat) and Patrol showed it green; rewritten for the Vana chat screen, passes (1 `logging` spend; 1 more spent on the original) | patrol-batch3.log, patrol-batch4.log |
| ai_credits_balance | pass | patrol-batch4.log |
| auth | fixed: a signed-in account without Pro lands on the paywall (mp-280/457); the flow now accepts shell or paywall, passes | patrol-auth.log, patrol-suite-rest.log |
| barcode_scanner_entry | pass | patrol-batch4.log |
| brick_plan | pass | patrol-batch4.log |
| energy_breakdown | pass | patrol-batch4.log |
| event_checklist_carbload | fixed: New Event is scrolled to (it rests under the tab bar, 03-007), passes | patrol-batch8.log |
| events_crud | fixed: same, passes | patrol-batch8.log |
| formula_create_pin | pass | patrol-batch4.log |
| formula_pin_conflict | not verified: skips at its precondition on the admin (no conflicting Before formula), red under fail-on-skip, 03-005 | patrol-batch4.log |
| formula_pin | pass | patrol-suite-rest.log |
| fueling_window_persistence | pass | patrol-suite-rest.log |
| google_login | not run: it drives the native Google sheet through ASWebAuthenticationSession, which iOS does not let Patrol automate; on iOS it only self-skips ("Android only"), and this wave has no Android | - |
| integrations_connect (3 cases) | Finding 03-008: all three hang to the 5-minute timeout after Connect (after the `--bundle-id` fix; before it xcodebuild exited 65) | patrol-clean-b.log |
| learn | pass | patrol-suite-rest.log |
| macro_dashboard | pass | patrol-suite-rest.log |
| meal_card_interaction | pass | patrol-suite-rest.log |
| meal_log_build | fixed: the probe read `components`, the column is `meal_logs.items`; passes | patrol-batch3.log |
| meal_plan_build | fixed in part (Confirm and the first tile are scrolled into view); Confirm acked and Shopping rendered, then red at its own precondition: no "Ate it" left on the first tile, 03-006. No new plan was generated (the admin had a draft); 1 `plan` spend taken beforehand | patrol-batch6.log |
| onboarding_signup | fixed test code (sweepable lee+e2e address, inline slider edit, no pumpAndSettle on the paywall); now red on an app bug, 03-009 | patrol-clean-c3.log |
| pro_gate | pass | patrol-suite-rest.log |
| recommendation_stacking (2 cases) | pass | patrol-suite-rest.log |
| settings_persist | pass | patrol-suite-rest.log |
| settings_sweep | pass | patrol-suite-rest.log |

Earlier results that do not count: suite attempts 1 and 2 (`patrol-suite-attempt1.log`,
`patrol-suite.log`) ran as the lapsed account; every green there was a silent skip (one Patrol
step, ~103 s each, 03-001).

Cost counter, wave 3: plan 1/3, logging 2/5, all ticket 03.
