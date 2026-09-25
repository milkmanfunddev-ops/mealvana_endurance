# 86-011 · Paywall menu Delete account with the network cut

- kind: followup-test
- status: closed
- ticket: 86
- run: w25-20260925T1324Z
- screen: Paywall
- decision: 

**Steps.**
1. A never-paid account on the paywall; `netcut.sh on` for the app.
2. ⋯ → Delete account → Delete.

**Expected.**
A clear failure message, the account and its local rows kept, and the athlete still signed in; no half
delete (local wiped, server kept).

**Actual.**
Not run. Online, the delete worked: Welcome, `[RevenueCatService] logged out`, no `public.users` or
`auth.users` row, no local rows.

**Evidence.**
- runs/86/35-after-delete-A.png
- runs/86/db-A-after-delete.txt

**Decision quote.**
> 

**Triage.**
Picked for retest ticket 107 (Lee, 2026-09-25).
Moved to retest ticket 121 when 107 was split (Lee, 2026-09-25).

Run by retest ticket 121 (run w34-20260925T2320Z, build e3367d2c): fail, carried by new bug Finding 121-007 (offline delete signs out and wipes locally, server account kept, no message).
