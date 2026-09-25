# 03-008 · integrations_connect hangs to its 5-minute timeout in all three cases on iOS once Connect is tapped

- kind: bug
- status: wontfix
- ticket: 03
- run: w3-20260923T1942Z
- screen: Connect Training Onboarding
- decision: 

**Steps.**
1. Clean install, then run `integration_test/flows/integrations_connect_flow_test.dart` with
   `--bundle-id com.milkman.mealvanaendurance.dev` (without it every native call fails at once:
   "Application com.milkman.mealvanaendurance is not running", see runs/03/patrol-clean-a.log).
2. Each case walks onboarding to Connect Training, taps a provider's Connect, then tries the
   native consent "Continue", the login form, "Sign" and "Cancel", and settles.

**Expected.**
Each case ends within a minute: the OAuth sheet opens, the flow cancels it, and the app is still
rendered (the flow's own claim: "tapping Connect launches OAuth without crashing").

**Actual.**
All three cases (finalsurge, garmin, trainingpeaks) run to the 5-minute test timeout. The Patrol
steps show the native Continue, enterText and Sign calls failing, and nothing after them; the
flow then ends in an unbounded `pumpAndSettle` and the native Cancel, one of which never returns.
The Garmin case also warns that `connect_training.garmin_connect_button` would not be hit by
the tap: on this screen the provider list shows TrainingPeaks, Final Surge and V.O2 above the
fold, with Garmin below it. Not fixed here: which call hangs needs a device session with the OAuth
sheet up, and iOS's ASWebAuthenticationSession is the part the flow's header already calls
not automatable. The flow is on the runner's exclusion list (clean-install).

**Evidence.**
- runs/03/patrol-clean-b.log (three cases, 298 to 300 s each)
- runs/03/device-clean-b.log, "Test timed out after 5 minutes" and the garmin hit-test warning
- runs/03/connect-training-during-garmin-case.png
- runs/03/patrol-clean-a.log (the earlier run without --bundle-id: xcodebuild 65)

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-25): iOS's ASWebAuthenticationSession sheet cannot be automated; the flow stays on the runner's exclusion list (interactive-oauth).
