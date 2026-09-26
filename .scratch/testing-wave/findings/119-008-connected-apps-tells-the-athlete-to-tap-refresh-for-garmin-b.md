# 119-008 · Connected Apps tells the athlete to tap Refresh for Garmin, but the button reads Sync Now

- kind: bug
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: Connected Apps
- decision: 

**Steps.**
1. On test@test.com, Settings > Connected Apps (00:42:21Z), read the Garmin card.

**Expected.**
The note names the button the athlete sees.

**Actual.**
The Garmin card's button reads "Sync Now"; the note under it says "Tap Refresh to pull any activities that arrived while the app was closed." There is no Refresh button.

**Evidence.**
- runs/119/27-connected-apps.png: Sync Now button and the "Tap Refresh" note

**Decision quote.**
> 

**Triage.**

Fix ticket 138, Settings, connections, allergies, Garmin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
