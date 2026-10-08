# 32-009 · Follow-up on Lee's phone: the real-payload half of the launch-trail guard (a delivered push tapped from killed and from background)

- kind: followup-test
- status: open
- ticket: 32
- run: w3-20261008T1256Z
- screen: none (startup chain, launch-trail dialog)
- decision: 

**Steps.**
1. On a device with notification permission granted, dev build: schedule or send a real notification
   carrying a `payload` (a carb_event nudge, or a flutter_local_notifications payload).
2. Kill the app, tap the banner: expect exactly one launch-trail dialog, and the tap routed.
3. Background the app, tap a second banner: one dialog at most, the tap routed (22-001 / ticket 34 says it is
   not collected today), and the trail shows `ios_un_response_payload` / `ios_legacy_resume_payload` on that resume.

**Expected.**
Exactly one dialog per process, only for a real payload; the backgrounded tap is collected once ticket 34 lands.

**Actual.**
Not run on the simulator: `xcrun simctl push` of a payload at 12:59:52Z was not delivered to the app's UN
delegate (the dev app has no notification authorization on the wave simulator, and step 5 answers the
prompt Don't Allow). The guard was fed instead through the native store (`defaults write` of
`ios_un_willpresent` and `ios_legacy_launch_payload`): one dialog each process, none for stale seeded keys.
A real payload on a device is still untested.

**Evidence.**
- runs/32/a07-fg-push.png no banner after the simulator push
- runs/32/a13-killed-legacy-payload-launch.png one dialog from the injected legacy launch payload
- runs/32/a15-cold-launch-stale-native-keys.png no dialog with stale keys only

**Decision quote.**
> 

**Triage.**
