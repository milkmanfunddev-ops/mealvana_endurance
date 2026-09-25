# 31-007 · Profile & Preferences: edit the Email field and save

- kind: followup-test
- status: triaged
- ticket: 31
- run: w11-20260924T1648Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. On a throwaway account, change the Email field and tap Save Changes.
2. Read public.users.email and auth.users.email by SQL; try logging in with the old and new address.

**Expected.**
Either the field is read-only, or the change goes through the auth email-change flow; public.users.email never differs from the login email.

**Actual.**
Not run. The field is editable and the save writes public.users.email directly (saveAllPreferences email:). Not tried on test@test.com because the ticket forbids changing its email.

**Evidence.**
- runs/31/06-profile-prefs.png: the editable Email field

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 93 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 119 when 93 was split (Lee, 2026-09-25).
