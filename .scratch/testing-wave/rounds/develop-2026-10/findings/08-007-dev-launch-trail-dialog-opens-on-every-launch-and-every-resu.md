# 08-007 · Dev 'Launch trail' dialog opens on every launch and every resume, because 'payload=null' counts as notification evidence

- kind: bug
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: Timeline (dev dialog over any screen)
- decision: 

**Steps.**
1. Cold start the dev build with no notification involved.
2. Background and resume (a system prompt, an openurl confirmation, the mobile MCP helper all do it).

**Expected.**
Per launch_trail.dart's hasNotificationEvidence doc, the dialog shows only for a launch or resume that carried a notification; an ordinary launch records silently.

**Actual.**
It opened on the first cold start, on the offline cold start, after the notification permission prompt, after the openurl 'Open in Endurance Dev?' prompt, and after each return to the app, over the Timeline and over /pro. The tape always holds 'launchDetails didNotificationLaunchApp=false payload=null', and the guard's `tape.contains('payload=')` matches it (launch_trail.dart:149, from code). The Dismiss button moves with the text length each time. The doc comment says the same dialog once broke every authenticating Patrol flow.

**Evidence.**
- runs/08/a02-after-relaunch-front.png first launch
- runs/08/b13-offline-cold-start.png offline launch (prompt then dialog)
- runs/08/console-redacted.log [LAUNCH] launchDetails line on each launch

**Decision quote.**
> 

**Triage.**
