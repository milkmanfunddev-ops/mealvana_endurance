# 119-013 · Profile & Preferences: save with an empty or malformed Email on a throwaway account

- kind: followup-test
- status: wontfix
- ticket: 119
- run: w36-20260926T0031Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. On a throwaway account, clear the Email field and Save; then type "not-an-email" and Save.
2. Read public.users.email by SQL after each.

**Expected.**
The form refuses both, or the field is read-only (see 119-002).

**Actual.**
Not run. 31-004's fix made an empty text field save as a clear (`clearEmail: currentState.email?.isEmpty`), so an empty Email may null public.users.email.

**Evidence.**
- runs/119/44-throwaway-profile.png: the editable Email field

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-26): moot, Email on Profile & Preferences becomes read-only (ticket 138).
