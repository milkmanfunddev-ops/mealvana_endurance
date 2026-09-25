# 86-010 · Profile & Preferences: tap a connected app's name suggestion and save

- kind: followup-test
- status: open
- ticket: 86
- run: w25-20260925T1324Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. Signed in as test@test.com, Settings → Profile & Preferences.
2. Tap "TrainingPeaks · Xuan Huang — tap to use", then Save Changes.
3. Read `public.users` first/last name and email on dev.

**Expected.**
Only the name fields change; the account's email stays the sign-in address (the 02-001 lesson).

**Actual.**
Not run. The screen offers the account's own connected apps' names (TrainingPeaks and Final Surge, "Xuan
Huang").

**Evidence.**
- runs/86/28-profile-preferences.png

**Decision quote.**
> 

**Triage.**
