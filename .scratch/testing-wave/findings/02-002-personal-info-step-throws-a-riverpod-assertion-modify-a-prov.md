# 02-002 · Personal info step throws a Riverpod assertion (modify a provider while building) when it applies the integration prefill

- kind: bug
- status: open
- ticket: 02
- run: w2-20260923T1442Z
- screen: Personal Info Onboarding
- decision: 

**Steps.**
1. Signed-out dev build on a device that holds a training-platform connection (here: TrainingPeaks, from an earlier user).
2. Walk onboarding to the Personal info step.

**Expected.**
No exception in the console.

**Actual.**
`EXCEPTION CAUGHT BY RIVERPOD: Tried to modify a provider while the widget tree was building.`
Stack: `OnboardingController._updateDraft` (onboarding_controller.dart:416) ←
`updatePersonalInfo` (:441) ← `_PersonalInfoScreenState._applyIntegrationProfile`
(personal_info_screen.dart:233) ← `initState` closure (:133). The screen still rendered.

**Evidence.**
- runs/02/console.log, the "EXCEPTION CAUGHT BY RIVERPOD" block after `screen_viewed {screen_name: Personal Info Onboarding}`

**Decision quote.**
> 

**Triage.**
