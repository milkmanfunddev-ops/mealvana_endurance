# 86-006 · user_registered analytics sends the user id as device_id

- kind: bug
- status: triaged
- ticket: 86
- run: w25-20260925T1324Z
- screen: Verify your email
- decision: 

**Steps.**
1. Onboard and sign up with email; enter the code (13:33:44Z).
2. Read the analytics lines in the console.

**Expected.**
`user_registered {device_id: …}` carries the device id, the same value `app_opened` sends
(C8EEF12E-60FE-49A1-80F8-6C51A4BE767D on this simulator), so Mixpanel can tie the registration to the
device's earlier anonymous events.

**Actual.**
`user_registered {device_id: 4dbde602-69d1-48cb-b984-2ca707702256, …}`: the new account's user id.
`OnboardingService` calls `trackUserRegistered(deviceId: user.id)`
(lib/features/onboarding/application/onboarding_service.dart:55). Screen was right; this is analytics only.

**Evidence.**
- runs/86/console-redacted.log (`user_registered` at 08:33:45 local, `app_opened` at 08:25:16 local)

**Decision quote.**
> 

**Triage.**
Fix ticket 104 (Lee, 2026-09-25). Closed by retest ticket 107 after it merges.
Moved to retest ticket 121 when 107 was split (Lee, 2026-09-25).
