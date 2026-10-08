# 67-003 · Follow-up: relaunch on Create Your Account before any account lands on Welcome; check what the athlete keeps

- kind: followup-test
- status: open
- ticket: 67
- run: w7-20261008T2308Z
- screen: Create Your Account
- decision: 

**Steps.**
1. Fresh install, Build My Plan, walk onboarding to Create Your Account (anonymous session, no account yet).
2. Terminate the app (or reboot the device) and relaunch.
3. Build My Plan again: are the earlier answers prefilled? Is the same anonymous auth user reused, or a second one made?
4. Variant: Continue without signing in, then relaunch.

**Expected.**
Either the app returns to Create Your Account with the answers kept, or it starts over on Welcome and reuses the anonymous user;
never an orphaned anonymous user per relaunch.

**Actual.**
Seen by accident: the simulator shut down at ~23:13:04Z while the app sat on Create Your Account (67-007). After a reboot and launch
(23:14:37Z) the app opened on Welcome (67-19b-after-reboot.png); tape `pending signup: none`. The anonymous user from 23:10:02Z
survived and was reused: account A's auth row shows `created_at 23:10:02Z` (db-67-A-after-verify.txt). Whether the onboarding
answers came back was not checked (the walk was redone by hand).

**Evidence.**
- runs/67/67-15-create-account.png
- runs/67/67-19b-after-reboot.png
- runs/67/db-67-A-after-verify.txt

**Decision quote.**
> 

**Triage.**

