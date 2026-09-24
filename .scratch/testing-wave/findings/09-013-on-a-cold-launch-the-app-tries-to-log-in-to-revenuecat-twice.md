# 09-013 · On a cold launch the app tries to log in to RevenueCat twice before the SDK is configured

- kind: idea
- status: open
- ticket: 09
- run: w7-20260924T1219Z
- screen: none
- decision: 

**Steps.**
1. Signed-in account, app terminated.
2. Cold launch, reading the Flutter lines from the simulator's unified log.

**Expected.**
The startup flow configures the RevenueCat SDK before anything asks it to log the user in, so no login attempt is skipped.

**Actual.**
`[RevenueCatService] logIn skipped: SDK not configured` appears twice, then `configured`, then `logged in` about 50 ms later. Nothing visible went wrong in either run, but a startup that depends on a later retry to identify the customer could, on a slow device, show the Gate the wrong customer's state for a moment. Seen in ticket 06's relaunch and again in 09's; both agents noted it in their run notes and filed nothing (filed by the wave lead at the wave 7 close).

**Evidence.**
- runs/09/console-relaunch-oslog.log
- runs/06/console-relaunch-oslog.log

**Decision quote.**
> 

**Triage.**
