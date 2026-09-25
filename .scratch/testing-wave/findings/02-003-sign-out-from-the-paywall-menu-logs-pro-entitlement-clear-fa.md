# 02-003 · Sign out from the paywall menu logs 'Pro entitlement clear failed' (settingsControllerProvider Ref used after dispose)

- kind: bug
- status: closed
- ticket: 02
- run: w2-20260923T1442Z
- screen: Paywall
- decision: 

**Steps.**
1. Signed in as a never-paid account (A2), on the paywall.
2. ⋯ → Sign out → Sign out.

**Expected.**
Sign-out completes with no error logged.

**Actual.**
Sign-out reached the welcome screen, but the console logs
`⛔ [SETTINGS] Pro entitlement clear failed` with
`Cannot use the Ref of settingsControllerProvider after it has been disposed`, from
`SettingsController.signOut` (settings_controller.dart:753). Whether the entitlement cache is
actually left behind was not checked (the next account signed in straight after and the Gate
showed the paywall correctly).

**Evidence.**
- runs/02/console.log, block after `settings_sign_out_tapped` (09:59:11 local)

**Decision quote.**
> 

**Triage.**
Fix ticket 33 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 86 (run w25-20260925T1324Z, build 5e05f8a6): pass, evidence in runs/86/verdicts.md.
