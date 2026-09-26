# 122-009 · Admin with no Pro on a truly slow network: time the two-second admin read

- kind: followup-test
- status: triaged
- ticket: 122
- run: w38-20260926T0340Z
- screen: Log In
- decision: 

**Steps.**
1. On the Patrol account (Admin, lapsed), give the app a slow but working network: Network Link Conditioner on a device ("Very Bad Network", or 3 s added latency), or a shim that delays packets without blocking the connecting thread.
2. Cold launch, and separately sign in. Record the screen and note the console's `GoRouter` and `[IS_ADMIN]` lines.

**Expected.**
mp-416: the Gate waits no more than about two seconds for the admin read and shows the paywall. When the slow read answers yes, the Gate reopens and the app moves into `/main` (the wave-27 late-yes rule). Startup waits at most two seconds (mp-335).

**Actual.**
This run could not time it. netcut only cuts, so I built a shim that sleeps inside `connect()` (SCRATCH/netslow.c). Sleeping there blocks the thread making the call, so every connect was serialized and the TLS handshake then failed: the start showed a blank screen with a small orange dot for 24-37 s, and the admin read failed with a HandshakeException before `/paywall`. That is a failing network, not a slow one, so neither the long blank start nor the paywall can be put on the app. What did pass: with the read failed the app lands on the paywall; with the network back, a resume re-reads the flag and goes to `/main`, and a cold launch goes straight in.

**Evidence.**
- runs/122/11-slow25-15.png (blank start under the blocking shim)
- runs/122/12-slow25-paywall.png
- runs/122/13-resume-after-network.png
- runs/122/14-relaunch-network-back.png
- runs/122/notes.md (12-006 entries)

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
