# 87-002 · An offline cold launch holds the splash about 12 s; Supabase init takes 5.5 s offline against 1.2 s online

- kind: bug
- status: open
- ticket: 87
- run: w25-20260925T1325Z
- screen: Splash
- decision: 

**Steps.**
Seen in follow-up test 06-001.
1. Account A, paid (Test Store Monthly), app on the timeline. Terminate the app.
2. Touch netcut's offline flag before the process starts, then launch with the netcut library injected (a cold launch that is offline from its first connect).
3. Screenshot every second.

**Expected.**
mp-335: "Startup waits for the Gate, at most two seconds". A paid account offline opens on the timeline after about the same splash as online.

**Actual.**
Launch 13:37:13.8Z. The splash logo stayed for at least 6 s (one screenshot a second) and the timeline showed by 13:37:37Z (behind the notification prompt). Console: Dart VM up 08:37:19.474 local, `Supabase init completed` 08:37:25.002 (5.5 s after the VM; the two online launches this run took 1.1 s and 1.4 s: 08:25:45.8→46.9, 08:26:02.5→03.9), then the saved RevenueCat copy (`active: true`) 08:37:25.656 and `/main` 08:37:26.159. The Gate itself answered within 1 s of Supabase init, so 06-001 passes; the extra wait is before the Gate, in Supabase init (probably a session refresh timing out offline). The launch-to-VM time is the debug build's own. On a phone with no signal an athlete stares at the logo for several seconds more than online.

**Evidence.**
- runs/87/20-A-06-001-offline-cold-launch-1s.png (…-6s.png: splash each second)
- runs/87/21-A-06-001-offline-10s.png (timeline)
- runs/87/console-redacted.log (`Dart VM service is listening` and `Supabase init completed` lines at 08:25:45, 08:26:02 and 08:37:19 local)

**Decision quote.**
> 

**Triage.**
