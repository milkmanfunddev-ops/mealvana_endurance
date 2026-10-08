# 22-002 · pullNative never reloads SharedPreferences: iOS writes during a session may never be seen

- kind: followup-test
- status: open
- ticket: 22
- run: w2-20261007T1340Z
- screen: none (startup chain, LaunchTrail)
- decision: 

**Steps.**
1. On a dev build, with the app in the foreground, trigger an iOS-side notification write (a delivered local notification, or a tap handled by the native UN delegate).
2. Resume the app and open the launch-trail dialog.
3. Check whether `native ios_un_response_payload=…` appears without a cold start.

**Expected.**
The trail shows the native write during the same session; if it does not, `pullNative()` needs `SharedPreferences.reload()` before reading (iOS keeps the Dart-side cache from launch).

**Actual.**
Not yet tried. `LaunchTrail.pullNative()` (`lib/shared/services/launch_trail.dart:103`) reads `prefs.getString` on the cached instance and never calls `reload()`; the Dart cache is filled once at startup, so a native write during the session may be invisible until the next launch. Retest home: ticket 32.

**Evidence.**
- `lib/shared/services/launch_trail.dart:103`
- `lib/shared/widgets/root_app_widget.dart:163` (the resume call)

**Decision quote.**
> 

**Triage.**
lead-filed; goes into retest ticket 32.

