# 06-001 · Cold relaunch of a paid account opens the timeline with no paywall frame (answers 05-007); the offline leg is still open

- kind: followup-test
- status: closed
- ticket: 06
- run: w6-20260924T1117Z
- screen: Timeline
- decision: 

**Steps.**
Done in this run (05-007 steps 1 and 2):
1. Account C bought Test Store Monthly at 11:28:36Z, signed out and back in (11:30–11:31Z).
2. 11:31:40Z `simctl terminate`, then 11:31:52Z `simctl launch`, recorded at 5 fps.

Still to run (05-007 step 3):
3. The same cold relaunch with the Mac's network off (or the simulator offline), inside the paid
   period, to prove the saved copy alone keeps the Gate open (mp-335: "works offline").

**Expected.**
Steps 1-2: the app opens on the timeline with no paywall frame (mp-457, mp-335). Step 3: the same
offline.

**Actual.**
Steps 1-2 pass. Frames: home screen, splash logo, startup spinner, one black frame (06-006), then
the timeline, with no paywall frame. The device log shows the router held `/` until RevenueCat
answered: `setting initial location /` at 06:31:55.154 local, `configured {store: test_store}`
and `customer info updated {active: true …}` at 55.36-56.35, `redirecting to RouteMatchList(/main)`
at 56.554. Startup waited about 1.4 s for the Gate, inside mp-335's two seconds. RevenueCat and
the Entitlement row were the same as after the purchase. 05-007 can close on steps 1-2. Step 3
(offline) was not run.

**Evidence.**
- runs/06/21-cold-relaunch-frames-5fps.png
- runs/06/17-after-cold-relaunch.png
- runs/06/console-relaunch-oslog.log (lines with `GoRouter`, `RevenueCatService`, `SubscriptionService`)
- runs/06/db-C-after-sign-in-and-relaunch.txt, runs/06/revenuecat-C-after-sign-in-and-relaunch.txt

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 87 (Lee, 2026-09-25).

Closed by retest ticket 87 (wave 25, build 5e05f8a6): pass, evidence in runs/87/verdicts.md.
