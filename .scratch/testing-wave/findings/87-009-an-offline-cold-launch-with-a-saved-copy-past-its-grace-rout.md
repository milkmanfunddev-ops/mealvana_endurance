# 87-009 · An offline cold launch with a saved copy past its grace routes to /main for 1.4 s before the paywall, 5.4 s after the router starts

- kind: bug
- status: triaged
- ticket: 87
- run: w25-20260925T1325Z
- screen: Startup (splash) → Paywall
- decision: 

**Steps.**
Retest of 07-002 (ticket 67).
1. Account A resubscribes at 14:16:31Z (Test Store monthly; the app's copy says `active: true`, expires 14:21:31Z, renewing). Terminate the app at 14:17:02Z and leave it closed.
2. At 14:37:15Z and again at 14:37:59Z, more than 15 minutes after the copy's expiry (grace ends 14:36:31Z), cold launch with netcut's offline flag set before the process starts. The second launch was recorded.
3. Turn the network back on (netcut off) at 14:38:40Z without touching the app.

**Expected.**
Ticket 67 / mp-335 with the mp-666 ruling: a saved copy more than 15 minutes past its own expiry counts as closed until a fresh answer arrives, so the Gate answers closed from the start and the router goes straight to /paywall; startup waits for the Gate at most two seconds. A fresh answer then opens the Gate.

**Actual.**
07-002's fix holds on screen: both launches ended on the full-screen paywall ("Plans aren't available right now. Please check back later." since offerings cannot load offline), and no timeline frame is visible in the recording (the 1.4 s falls on the startup spinner and a black frame). But the router went to /main first: second launch, `setting initial location /` 09:38:02.065 local, `customer info fetched {active: true, expires_at: …14:21:31…}` at 02.543 and again at 07.416 (after a ~5 s offline wait), `redirecting to RouteMatchList(/main)` 09:38:07.468, then `/paywall` 09:38:08.885. The first launch did the same (/main 09:37:24.067, /paywall 09:37:25.473). So the first Gate answer counted the expired copy as open, and startup waited 5.4 s, not two. On a faster phone the timeline could show for over a second. Step 3 passed: back online, the app fetched on its own (`expires_at 14:41:31`, 09:38:41.302) and went to /main with no resume.

**Evidence.**
- runs/87/30-A-07-002-offline-launch-frames-2fps.png (tile, 2 fps, 11 per row: paywall before the terminate, home, splash, spinner, black, the paywall's video, paywall)
- runs/87/28-A-07-002-offline-cold-launch-4s.png (…-16s.png, first launch)
- runs/87/29-A-07-002-offline-paywall.png
- runs/87/31-A-07-002-online-20s-later.png (timeline after the network came back)
- runs/87/console-redacted.log (09:37:16-09:37:26 and 09:38:00-09:38:41 local, `SubscriptionService` and `GoRouter` lines)

**Decision quote.**
> 

**Triage.**
Fix ticket 105 (Lee, 2026-09-25): the Gate's first answer applies the 15-minute cutoff and startup waits at most two seconds. Closed by retest ticket 107 after it merges.
