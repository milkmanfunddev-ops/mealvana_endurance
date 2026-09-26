# 119-012 · Profile & Preferences: save offline, then sign out while still offline

- kind: followup-test
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. On a throwaway account, cut the network (`netcut.sh on --relaunch`), change a field on Profile & Preferences, Save.
2. Still offline, Settings > Sign Out > Sign out.
3. Back online, sign in again and read the field in the app and by SQL.

**Expected.**
The Sign out dialog says "Your data stays with your account": the change reaches the server, or sign-out warns that unsent changes will be lost.

**Actual.**
Not run. 119-001 showed the unsent profile change waits for sign-out's own upload; offline that upload cannot succeed.

**Evidence.**
- runs/119/30-signout-dialog.png: "Your data stays with your account."

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
