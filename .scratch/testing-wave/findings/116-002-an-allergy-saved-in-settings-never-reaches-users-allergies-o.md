# 116-002 · An allergy saved in Settings never reaches users.allergies on the server

- kind: bug
- status: open
- ticket: 116
- run: w32-20260925T2220Z
- screen: Allergies (Settings)
- decision: 

**Steps.**
1. New account lee+e2e-116-20260925T2244Z (user 5cafdf6d…), paid. Settings > Diet, Allergies & Formulas > Allergies: Peanuts, Save at 22:48:13Z; later add Gluten, Save at 22:49:47Z. Both show "Allergies updated" and the hub reads "1 allergy selected" / "2 allergies selected".
2. SELECT allergies, updated_at FROM users WHERE id = the account, at 22:48:16Z, 22:48:30Z, 22:49:11Z, 22:49:55Z and 22:57:13Z.

**Expected.**
The saved allergies reach `users.allergies` on the server (Vana's meal planning and the server-side plan builder read the profile from there), within seconds or at the next sync.

**Actual.**
`users.allergies` stayed `{}` and `users.updated_at` stayed 22:46:15Z (signup) through all five reads, the last nine minutes after the first save. The app used the allergies locally (the Formula Library hid gluten formulas and warned on a gluten pin), so the change lives only on the phone. The account was deleted at 22:57:45Z, so it is not known whether a later sync would have sent it. The allergies screen's settings branch calls `saveAllergies` (lib/features/onboarding/presentation/screens/allergies_screen.dart:148); not traced further (no fixing in a run).

**Evidence.**
- runs/116/db-newacct-allergies.json (the reads, all `{}`)
- runs/116/console-excerpt-allergies.txt (allergies_saved / allergies_changed at 17:48:13 and 17:49:46 local)
- runs/116/76-allergies-gluten-peanuts.png
- runs/116/notes.md (New account section)

**Decision quote.**
> 

**Triage.**

