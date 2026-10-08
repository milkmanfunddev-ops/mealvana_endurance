# 50-008 · iOS sign-in prompt for V.O2 names the app 'mealvana_endurance' (CFBundleName) instead of its display name

- kind: bug
- status: closed
- ticket: 50
- run: w5-20261008T1720Z
- screen: Connected Apps (V.O2 Connect → iOS ASWebAuthenticationSession prompt)
- decision: 

**Steps.**
1. Settings → Connected Apps → V.O2 Connect.

**Expected.**
The system prompt names the app as athletes know it ("Endurance Dev" on dev, the store name on prod).

**Actual.**
"“mealvana_endurance” Wants to Use “vdoto2.com” to Sign In". From code (unverified): `ios/Runner/Info.plist` has
`CFBundleName = mealvana_endurance` (CFBundleDisplayName is `$(BUNDLE_DISPLAY_NAME)`); iOS uses the bundle name in
this prompt. TrainingPeaks' sheet is ephemeral and shows no prompt, so V.O2 (and any non-ephemeral web auth) is where
athletes see it. Prod not checked (this run touches dev only).

**Evidence.**
- runs/50/o01-vo2-connect.png the prompt

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 69 check 9) · lead, 2026-10-09
