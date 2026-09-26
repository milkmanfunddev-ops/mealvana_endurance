# 122-002 · The coach cannot see, accept or decline a code pairing anywhere in the iOS app

- kind: bug
- status: triaged
- ticket: 122
- run: w38-20260926T0340Z
- screen: Coach Portal
- decision: 

**Steps.**
1. Two new athletes redeem the coach codes: A enters DEVCOACH30, B enters DEVCOACH18 (both owned by test@test.com). Each gets "Code redeemed. Your coach will see your request to pair." and a `coach_athlete_relationships` row with `status pending`, `requested_by athlete` (e2b98821…, 79e9b6a1…).
2. Sign in as test@test.com on iOS. The tab bar (Timeline, Food, Events, Learn) and Settings show no coach entry; in the code, the coach tab and the post-login jump to `/coach-portal` exist only under `kIsWeb`.
3. Open the coach portal by deep link: `xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///coach-portal"`.

**Expected.**
11-009: the coach sees each request as an athlete-requested pairing and can accept or decline it; the athlete's view follows. mp-458: "an athlete entering a coach Code gets a pending pairing with that coach".

**Actual.**
No iOS screen offers it. `/coach-portal` is only navigated to when `kIsWeb` (email_login_screen.dart, tabs_screen.dart), so no tap reaches it on a phone. Through the deep link, Coach Portal lists 7 athletes, all "Active", and neither pending request. The accept and decline calls (`CoachService.acceptAthleteRequest` / `declineAthleteRequest`) are made only from `CoachDashboardController`, and its `CoachDashboardScreen` is mounted by no route or screen. So a code pairing can only stay pending in the app: accept, decline and "redeem again after a decline" could not be run (no database writes were made by hand). The web coach app is out of the testing spec's scope and was not tried.

**Evidence.**
- runs/122/35-coach-portal.png (Coach Portal on test@test.com: 7 Active, no pending)
- runs/122/db-B-after-codes.txt (B's pending pairing)
- runs/122/28-A-devcoach30-closed-1.png (A's paired message)
- runs/122/notes.md (04:01Z-04:02Z entries)

**Decision quote.**
> 

**Triage.**

Fix ticket 140, Paywall, purchases, codes, coach pairing (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
