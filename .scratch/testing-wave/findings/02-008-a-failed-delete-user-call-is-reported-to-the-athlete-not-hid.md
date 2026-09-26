# 02-008 · A failed delete-user call is reported to the athlete, not hidden behind a normal sign-out

- kind: followup-test
- status: closed
- ticket: 02
- run: w2-20260923T1442Z
- screen: Paywall
- decision: 

**Steps.**
1. Signed in, on the paywall. 2. Make delete-user fail: airplane mode / network link conditioner off-line, or a dev-only fault. 3. ⋯ → Delete account → Delete.

**Expected.**
The app says the account was not deleted and keeps the athlete signed in. Read from the code: SettingsController.deleteAccount logs a non-200 or a throw and then clears local data, signs out and lands on welcome anyway, so today a failed delete looks the same as a successful one. Check the auth user and public.users by SQL afterwards (sweep-accounts.mjs footprint).

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 125 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 125 (run w37-20260926T0221Z, build 72d3723e): fail, carried by open bug Finding 121-007 (a failed delete-user call, offline, still ends on Welcome with no message and the server account kept).
