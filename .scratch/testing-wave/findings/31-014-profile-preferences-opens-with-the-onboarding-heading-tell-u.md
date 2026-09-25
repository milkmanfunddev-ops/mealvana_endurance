# 31-014 · Profile & Preferences opens with the onboarding heading Tell us about yourself and no screen title

- kind: idea
- status: closed
- ticket: 31
- run: w11-20260924T1648Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. Settings > Profile & Preferences.

**Expected.**
A settings screen titled for what it is (for example "Profile & Preferences") with a back control at the top.

**Actual.**
Idea: the screen reuses the onboarding heading "Tell us about yourself" and "This helps us calculate accurate nutrition plans", has no title bar, and its only back control is the orange arrow beside Save Changes at the bottom. Saving pops straight back to Settings with "Preferences saved successfully".

**Evidence.**
- runs/31/06-profile-prefs.png: top of the screen
- runs/31/09-after-save.png: back on Settings after save

**Decision quote.**
> 

**Triage.**
Fix ticket 80 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.

Closed by retest ticket 86 (run w25-20260925T1324Z, build 5e05f8a6): pass, evidence in runs/86/verdicts.md.
