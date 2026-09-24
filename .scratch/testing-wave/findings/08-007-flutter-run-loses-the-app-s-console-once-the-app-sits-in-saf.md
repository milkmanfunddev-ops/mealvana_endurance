# 08-007 · flutter run loses the app's console once the app sits in Safari after Manage subscription, so the rest of the run's console must come from the simulator log

- kind: idea
- status: open
- ticket: 08
- run: w7-20260924T1216Z
- screen: Subscription
- decision: 

**Steps.**
Tapping Manage subscription sends the app to Safari. About 35 s later (12:27:52Z → 12:28:27Z) `flutter run` printed "The OS has terminated the Flutter debug connection for being inactive in the background for too long" and captured no more lines, though the app kept running. The rest of this run's console came from `xcrun simctl spawn <udid> log stream` (console-oslog.log), started at 12:36Z, so 12:28–12:36Z has no console.
Idea: the runbook's step 5 also starts a `log stream` for the app's process next to `flutter run` from the start, so any ticket that leaves the app (Manage, store sheets, OAuth, Safari links) keeps its console.

**Expected.**
-

**Actual.**
-

**Evidence.**
- runs/08/console.log (line 475)
- runs/08/console-oslog.log

**Decision quote.**
> 

**Triage.**
