# 21-003 · The Kroger sign-in system alert names the app mealvana_endurance instead of its display name
- kind: bug
- status: triaged
- ticket: 21
- run: w17-20260924T2233Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. On Shop with Kroger, disconnected, tap Connect Kroger (22:38 UTC).

**Expected.**
The iOS alert names the app as the athlete knows it ("Endurance Dev" on dev, "Mealvana" or the store name in prod).

**Actual.**
The alert reads "“mealvana_endurance” Wants to Use “kroger.com” to Sign In". iOS takes the name from `CFBundleName`, which is the project slug `mealvana_endurance` in `ios/Runner/Info.plist`; the home-screen name comes from `CFBundleDisplayName`. Prod would show the same slug to every shopper who connects Kroger.

**Evidence.**
- runs/21/16-sheet-01-after-connect-tap.png

**Decision quote.**
> 

**Triage.**
Fix ticket 56 (Lee, 2026-09-25). Closed by the retest after it merges.
