# 08-005 · Subscription screen on return from Manage subscription, and Manage tapped twice or offline

- kind: followup-test
- status: triaged
- ticket: 08
- run: w7-20260924T1216Z
- screen: Subscription
- decision: 

**Steps.**
1. Settings → Subscription → Manage subscription, stay in Safari/App Store for a minute, come back.
2. Tap Manage twice quickly.
3. Tap Manage with the network off.
4. Cancel in the store while the screen is open, then return.

**Expected.**
The screen refreshes on return and shows what RevenueCat has (a cancel turns "Renews on" into "Ends on"). One store page opens per tap. Offline, the store page or the "Manage your subscription in the App Store or Google Play app" message shows and the screen stays usable.

**Actual.**
Not run beyond step 1. Back from Safari at 12:28:27Z, the screen still read "Renews on September 24, 2026."; whether it refetched is unknown because the console had dropped (08-007). See 07-011 for the same question after Home and resume.

**Evidence.**
- runs/08/12-after-manage.png
- runs/08/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 123 when 107 was split (Lee, 2026-09-25).
