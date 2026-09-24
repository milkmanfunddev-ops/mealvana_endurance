# 31 run notes: w11-20260924T1648Z

- App on UDID 0AEDF069-15AA-4C1C-AF72-E61257845724 (wave-pool-2) built from commit
  52c68764b2cde49951a27220a8dbdb3a463116f7.
- Worktree base dcc4a14ebb9f3c67c530dff2a6632c044dac5f98. Slot claimed 16:48 UTC.
- Setting changed: runs_with_water_bottle (Profile & Preferences > water bottle toggle). See expected.md.
- Harness: the mobile MCP's `mobile_list_elements_on_screen` for UDID returned another simulator's
  screens (first the home screen, then a signed-in Food tab) while `simctl io` showed my app on
  Welcome/Log In. Taps from the MCP did land on UDID. From 16:50 UTC I drove the app only with
  `idb ui tap/text/describe-all --udid UDID`. Known noise: MCP helper routing, not the app.
- 16:50:52 UTC logged in as test@test.com; "New in Mealvana: Shake to tell us" sheet shown over Timeline (existing finding 12-008 / 30-010 cover stacked first-login sheets).
- Console 11:50:58 local: TrainingPeaks token refresh 400, V.O2 "Please reconnect" on login. Known noise: the dev admin's integration tokens are expired (runs 16 notes, finding 03-008).
- First tap on the Settings gear straight after "Got it" did nothing; the second tap opened Settings. See finding 31 on gear tap.
- 16:51 UTC Profile & Preferences: water bottle unchecked (matches DB false). Chips offer "Xuan Huang", "Female", "Aug 1982" from TrainingPeaks/Final Surge: the dev admin's integrations are Xuan's accounts; followup 31-006, onboarding version is 02-001. Heading reuses onboarding copy: idea 31-014. The checkbox has no a11y state: bug 31-002.
- 16:52:05 UTC checked + Save Changes: "Preferences saved successfully", popped to Settings. SQL: runs_with_water_bottle true, updated_at 16:52:05; unit_system imperial and dietary_preference vegetarian unchanged (db-after-change.txt).
- 16:52:22 UTC terminate + launch. iOS notification permission prompt showed on this second launch (not on the first); tapped Don't Allow (followup 31-010). Timeline opened signed in. Profile & Preferences shows the box checked (12-relaunch-bottle-kept.png); SQL still true (db-after-relaunch.txt).
- 16:53:10 UTC unchecked + Save Changes. SQL: runs_with_water_bottle false, updated_at 16:53:11 (db-after-restore.txt). Original value restored.
- Appearance dialog opened (Dark selected), dismissed by tapping outside; nothing changed.
- 16:54:04 UTC Sign Out: dialog promises a guest session (ssot-conflict 31-001, mp-508). Confirm -> Welcome. 16:54:15 terminate + launch -> Welcome, still signed out. No DB change from sign-out (db-after-signout.txt).
- After sign-out, console still shows `[SubscriptionService] customer info updated {active: true ...}` at 11:54:05 and after relaunch at 11:54:21 local: already filed as 03-002 (RevenueCat SDK stays identified after sign-out); cited in 31-012.
- Console: only Flutter warnings were the known integration noise above plus "No distance data available" / "No intensity distribution hints" (known noise: fuelling-engine defaults for Patrol test activities, runs/16 notes). Non-Flutter lines (UIAccessibility notifications, CFBundle strings, CoreHaptics pattern errors) are simulator noise.
- console.log had 8 token-scan hits, so it was deleted and console-excerpts.log keeps the cited lines.
- 16:54 UTC log stream stopped (own PID), app terminated, slot released. COST: nothing spent.
