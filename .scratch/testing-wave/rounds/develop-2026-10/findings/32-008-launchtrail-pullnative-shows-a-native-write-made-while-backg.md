# 32-008 · LaunchTrail.pullNative() shows a native write made while backgrounded one resume late in 2 of 3 tries (retest of 22-002)

- kind: bug
- status: open
- ticket: 32
- run: w3-20261008T1256Z
- screen: none (startup chain, LaunchTrail)
- decision: 

**Steps.**
1. Dev build, signed out on Welcome. Background the app (HOME).
2. Write a native key the way AppDelegate does: `xcrun simctl spawn UDID defaults write <app data
   container>/Library/Preferences/com.milkman.mealvanaendurance.dev flutter.ios_un_willpresent "#0 payload=… at=…"`
   (no real notification could be delivered: the app has no notification authorization on the simulator).
3. Resume from the icon and read the `[LAUNCH] native …` lines; repeat with new values.

**Expected.**
Each resume's `pullNative()` tapes the value written while the app was away (22-002's question).

**Actual.**
Probe 1 (written 13:00:28Z, resume 13:00:31Z): taped on that resume. Probe 2 (written 13:01:10Z, resume
13:01:11Z): not taped; it appeared on the next resume (13:01:48Z). Probe 3 (`flutter.ios_un_response_payload`,
written 13:01:43Z, resume 13:01:48Z): not taped; it appeared on the resume after (13:02:08Z). `defaults read`
showed each value in the store before its resume. `pullNative()` (`lib/shared/services/launch_trail.dart`)
reads `prefs.getString` from the cached legacy `SharedPreferences` instance (shared_preferences 2.5.3's
`getString` reads `_preferenceCache`), and no `reload()` exists anywhere in `lib/`; what refreshes the
cache at all, a resume late, is not visible in the code. So a backgrounded tap's native payload can be
missing from the dev dialog shown on its own resume.

**Evidence.**
- runs/32/a08-resume-after-native-write.png probe 1 taped, one dialog
- runs/32/a09-second-evidence-resume-no-dialog.png probe 2 not taped on its resume
- runs/32/console-redacted.log `[LAUNCH] native ios_un_willpresent=…probe-2` at 08:01:48 and `ios_un_response_payload=wave32-bg-probe-3` at 08:02:08
- runs/32/notes.md Step 1

**Decision quote.**
> 

**Triage.**
