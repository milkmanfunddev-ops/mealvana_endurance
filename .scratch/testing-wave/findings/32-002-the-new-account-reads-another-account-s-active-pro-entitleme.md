# 32-002 · The new account reads another account's active Pro entitlement for 0.3 s after the code is accepted

- kind: bug
- status: open
- ticket: 32
- run: w9-20260924T1447Z
- screen: Verify your email
- decision: 

**Steps.**
1. Start on a simulator where an earlier account had Pro and signed out (here: the wave simulator, a copy of the dev simulator).
2. Onboard, sign up with email, type the right code and tap Verify.
3. Read the console around `email_verification_completed`.

**Expected.**
A brand-new, never-paid account never reads as Pro, not even for a frame. The first
`SubscriptionService` line after sign-up says `active: false`.

**Actual.**
40 ms after `email_verification_completed` (09:52:42.83 local) the app logs
`[SubscriptionService] customer info updated {active: true, expires_at: 2027-09-15T19:39:14.000Z}`.
0.3 s later, after `[RevenueCatService] logged in`, it flips to `active: false` and the router
sends the account to the paywall, so the screen was right this time. The account had existed for
two minutes and bought nothing; `public.user_entitlements` has no row for it. The expiry belongs
to some earlier account on the device.

This is the leftover that Finding 02-003 suspected: sign-out's "Pro entitlement clear" fails
(`Cannot use the Ref of settingsControllerProvider after it has been disposed`), and this run hit
the same failure again when it signed out from the paywall (09:53:37). Whose cache it was cannot be
told from the log (the simulator is a copy of the dev simulator, IMPROVEMENTS #31). The risk is
a race: any screen or gate that reads the entitlement in that 0.3 s window sees Pro, and on a slow
network the window is longer.

**Evidence.**
- runs/32/console-excerpts.log, section A (09:52:42.83 `email_verification_completed`, 09:52:42.87 `active: true, expires_at: 2027-09-15…`, 09:52:43.18 `active: false`)
- runs/32/console-excerpts.log, section B (09:53:37 `Pro entitlement clear failed`)
- runs/32/db-auth-user-after-code.txt (no `user_entitlements` row)
- runs/32/11-onboarding-paywall.png

**Decision quote.**
> 

**Triage.**
