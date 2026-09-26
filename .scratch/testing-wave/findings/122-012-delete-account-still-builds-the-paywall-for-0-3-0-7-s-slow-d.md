# 122-012 · Delete account still builds the paywall for 0.3-0.7 s: slow device and network

- kind: followup-test
- status: triaged
- ticket: 122
- run: w38-20260926T0340Z
- screen: Settings
- decision: 

**Steps.**
1. On a device (slower than the simulator) and on a slow network, delete an account from Settings that holds Pro from a code.
2. Record the screen and read the console from the Delete tap to Welcome.

**Expected.**
No paywall frame and no paywall work for an account being deleted (87-003).

**Actual.**
On the simulator 87-003 passes on screen: in three deletes (C, D, A) no paywall frame shows at 10 fps; Settings stays until Welcome slides in. But the router still goes to `/paywall` first (0.63 s, 0.56 s and 0.72 s), and each time the paywall is built: `offerings fetched` right after the redirect, before RevenueCat's `logged out`. On a slower device or network that hop may become a visible frame, or trigger the paywall clip or any paywall analytics.

**Evidence.**
- runs/122/43-C-87-003-frames-1.5to5.5s.png
- runs/122/47-D-87-003-frames-1.5to5.5s.png
- runs/122/console-redacted.log (23:06:01.678, 23:08:40.095, 23:11:15.290 local)

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
