# 04-001 · Deleting an account from the paywall menu is tracked as settings_delete_account_tapped

- kind: idea
- status: triaged
- ticket: 04
- run: w4-20260924T0418Z
- screen: Paywall
- decision: 

**Steps.**
1. A new account on the paywall: ⋯ → Delete account → Delete.
2. Read the console's analytics lines.

**Expected.**
Analytics can tell a delete from the paywall apart from a delete in Settings, so we can see how many
new accounts delete themselves without subscribing (the case mp-494's example describes).

**Actual.**
The only event is `settings_delete_account_tapped {}`, because the paywall reuses
`SettingsController.deleteAccount()`, which tracks that name. Nothing says the delete came from the
paywall. The delete itself worked (footprint empty, delete-user logged success). Idea: pass a
source to the tracked event.

**Evidence.**
- runs/04/console.log (`settings_delete_account_tapped {}` right after `going to /paywall?onboarding=1`)
- lib/features/settings/presentation/providers/settings_controller.dart (the track call)
- lib/features/subscription/presentation/screens/paywall_screen.dart, `_deleteAccount`

**Decision quote.**
> 

**Triage.**
Fix ticket 50 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 115 when 91 was split (Lee, 2026-09-25).
