# 31-006 · Profile & Preferences: the tap-to-use chips from TrainingPeaks and Final Surge

- kind: followup-test
- status: open
- ticket: 31
- run: w11-20260924T1648Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. On test@test.com open Profile & Preferences; chips read "TrainingPeaks · Xuan Huang — tap to use", "Final Surge · Xuan Huang — tap to use", "TrainingPeaks · Female — tap to use", "TrainingPeaks · Aug 1982 — tap to use".
2. Tap each chip, check what fills, then leave without saving (or save and restore on a throwaway account).

**Expected.**
Tapping a chip fills only that field, marks the form changed, and nothing is written until Save Changes.

**Actual.**
Not run. The chips carry another person's details because the dev admin's integrations are connected to Xuan's accounts (see 02-001 for the onboarding version of this).

**Evidence.**
- runs/31/06-profile-prefs.png: the chips

**Decision quote.**
> 

**Triage.**
