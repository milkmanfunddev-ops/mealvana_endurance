# 118-007 · A refused TrainingPeaks or V.O2 connection is shown only inside Connected Apps; nothing on Timeline tells the athlete, and the card says Last synced 1 minute ago

- kind: idea
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: Timeline; Settings → Connected Apps
- decision: 

**Steps.**
1. Idea, from the 21-004 retest. Today an athlete whose TrainingPeaks or V.O2 token is refused
   learns it only by opening Settings → Connected Apps. Product question for Lee: should the app
   say it once where the athlete already is (a line on Timeline or a one-time message after the
   sync that finds it, naming the connection and offering Reconnect)? 21-004's Expected asked for
   "tells the athlete once, on screen, which integration needs reconnecting"; fix ticket 64 chose
   Connected Apps only.
2. Also: a card that says Reconnect also says "Last synced: 1 minute ago", which reads as working.
   `last_sync_at` is the last attempt; the card could show the last successful sync instead, or
   "Last tried".

**Expected.**
Lee decides whether a refused connection is announced outside Connected Apps.

**Actual.**
After sign-in (00:40:44Z) the sync marked TrainingPeaks and V.O2 `requires_reauth`; the Timeline
showed nothing about it (What's New sheet, then the plain timeline). Connected Apps showed Reconnect
with "Sign in again to keep your workouts syncing." and "Last synced: 1 minute ago" on both.

**Evidence.**
- runs/118/36-timeline.png: Timeline after the sign-in sync, no notice.
- runs/118/41-connected-apps.png: Reconnect with "Last synced: 1 minute ago".

**Decision quote.**
> 

**Triage.**

Fix ticket 138, Settings, connections, allergies, Garmin (Lee, 2026-09-26). Ruling: when a sync finds that TrainingPeaks or V.O2 needs signing in again, show a one-time notice naming it, with Reconnect. The card shows the last successful sync, not the last attempt (138). Closed by the retest after it merges. Record: `triage-20260926.md`.
