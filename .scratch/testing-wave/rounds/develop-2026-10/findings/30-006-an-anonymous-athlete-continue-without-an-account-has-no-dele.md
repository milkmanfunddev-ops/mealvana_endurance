# 30-006 · An anonymous athlete (Continue without an account) has no Delete Account; the anonymous auth user and its rows stay on the server

- kind: bug
- status: wontfix
- ticket: 30
- run: w3-20261008T1255Z
- screen: Settings
- decision: Lee: the anonymous path is being removed; its server rows are swept by that removal (noted in .scratch/branch-split/HANDOFF.md)

**Steps.**
1. Signed out. Welcome → Build My Plan (mints anonymous user a8e2c6a5-b533-4567-9843-c25129e3ac83 at 13:18:41Z) → onboarding →
   Create account → Continue without an account (13:20:00Z). Timeline opens.
2. Gear → Settings. Look for Delete Account; scroll the whole list.

**Expected.**
01-015 as written: delete the anonymous account from Settings; `footprint` reports nothing and the anonymous auth
user is gone.

**Actual.**
The Account card shows "Not signed in", "Create an account to save your data" and "Log into an existing account".
There is no Delete Account anywhere (from code: `settings_screen.dart:455` shows the delete control only in the
signed-in branch). The anonymous user keeps auth.users 1, public.users 1, daily_macro_targets 7, onboarding_surveys 1.
Logging in to another account from that screen (13:21:16Z) left the anonymous rows in place as well (footprint
re-read after the B login). The athlete's onboarding data (weight, sex, birth year) cannot be removed by them.
Retest of 01-015. The anonymous user is listed under Leftover accounts in notes.

**Evidence.**
- runs/30/30b3-08-anon-settings.png
- runs/30/30b3-09-anon-settings-bottom.png
- runs/30/footprint-anon-a8e2.txt
- runs/30/footprint-anon-a8e2-after-B-login.txt

**Decision quote.**
> 

**Triage.**
